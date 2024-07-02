//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Stablecoin} from "./Stablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SCEngine is ReentrancyGuard {
    //errors

    error SCEngine__NeedsMoreThanZero();
    error SCEngine__TokenNotAllowed();
    error SCEngine__TokenAddressesAndPriceFeedAddressesLengthsDontMatch();
    error SCEngine__TransferFailed();
    error SCEngine__BreaksHealthFactor(uint256 healthFactor);
    error SCEngine__MintFailed();
    error SCEngine__AmountShouldBeLessThanCollateral();
    error SCEngine__BurnAmountExceedsSCMinted();
    error SCEngine__HealthFactorOk();
    error SCEngine__HealthFactorNotImproved();
    // State variables

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECESION = 1e18;
    uint64 private constant LIQUIDATION_THRESHOLD = 20;
    uint64 private constant LIQUIDATION_PRECESION = 100;
    uint64 private constant LIQUIDATION_BONUS = 10;
    uint64 private constant MIN_HEALTH_FACTOR = 1e18;

    Stablecoin private immutable i_sc;

    mapping(address collateralToken => address priceFeed) private s_pricefeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_userCollateralAmounts;
    mapping(address user => uint256) private s_SCMinted;
    address[] private s_collateralTokens;

    // Events
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed collateralToken, uint256 amount);

    // modifiers

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert SCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isTokenAllowed(address token) {
        if (s_pricefeeds[token] == address(0)) {
            revert SCEngine__TokenNotAllowed();
        }
        _;
    }

    // Constructor
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address _stablecoin) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert SCEngine__TokenAddressesAndPriceFeedAddressesLengthsDontMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_pricefeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_sc = Stablecoin(_stablecoin);
    }

    // External functions
    function depositCollateralAndMintSC(uint256 amount, address collateralToken, uint256 amountSCToMint)
        external
        moreThanZero(amount)
        moreThanZero(amountSCToMint)
        isTokenAllowed(collateralToken)
        nonReentrant
    {
        depositCollateral(amount, collateralToken);
        mintSC(amountSCToMint);
    }

    function redeemCollateralAndBurnSC(uint256 amount, address collateralToken, uint256 amountToBurn)
        external
        moreThanZero(amount)
        moreThanZero(amountToBurn)
        isTokenAllowed(collateralToken)
        nonReentrant
    {
        redeemCollateral(amount, collateralToken);
        burnSC(amountToBurn);
    }

    function liquidate(address collateral, address user, uint256 debtToCovered)
        external
        moreThanZero(debtToCovered)
        isTokenAllowed(collateral)
        nonReentrant
    {
        uint256 startingHealthFactor = healthFactor(user);
        if (startingHealthFactor > MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebt = getTokenAmountFromUSD(collateral, debtToCovered);
        uint256 bonusCollateral = tokenAmountFromDebt * LIQUIDATION_BONUS / LIQUIDATION_PRECESION;
        uint256 totalCollateral = tokenAmountFromDebt + bonusCollateral;
        _redeemCollateral(collateral, totalCollateral, user, msg.sender);
        _burnSC(debtToCovered, user, msg.sender);
        uint256 endingHealthFactor = healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingHealthFactor <= startingHealthFactor) {
            revert SCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    // Public functions

    function depositCollateral(uint256 amount, address collateralToken)
        public
        moreThanZero(amount)
        isTokenAllowed(collateralToken)
        nonReentrant
    {
        s_userCollateralAmounts[msg.sender][collateralToken] += amount;
        emit CollateralDeposited(msg.sender, collateralToken, amount);
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function redeemCollateral(uint256 amount, address collateralToken)
        public
        moreThanZero(amount)
        isTokenAllowed(collateralToken)
        nonReentrant
    {
        _redeemCollateral(collateralToken, amount, msg.sender, msg.sender);
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    function mintSC(uint256 amountSCToMint) public moreThanZero(amountSCToMint) nonReentrant {
        s_SCMinted[msg.sender] += amountSCToMint;
        _revertIfHealthFactorBelowThreshold(msg.sender);
        bool minted = i_sc.mint(msg.sender, amountSCToMint);
        if (!minted) {
            revert SCEngine__MintFailed();
        }
    }

    function burnSC(uint256 amount) public moreThanZero(amount) nonReentrant {
        _burnSC(amount, msg.sender, msg.sender);
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    // Internal functions

    function _burnSC(uint256 amount, address onBehalfOf, address dscFrom) internal {
        uint256 userSCMinted = s_SCMinted[onBehalfOf];
        if (amount > userSCMinted) {
            revert SCEngine__BurnAmountExceedsSCMinted();
        }
        s_SCMinted[onBehalfOf] -= amount;
        bool success = i_sc.transferFrom(dscFrom, address(this), amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
        i_sc.burn(amount);
    }

    function _revertIfHealthFactorBelowThreshold(address user) internal view {
        uint256 _healthFactor = healthFactor(user);
        if (_healthFactor <= MIN_HEALTH_FACTOR) {
            revert SCEngine__BreaksHealthFactor(_healthFactor);
        }
    }

    function _redeemCollateral(address collateralToken, uint256 amount, address from, address to) internal {
        uint256 userCollateralAmount = s_userCollateralAmounts[from][collateralToken];
        if (amount < userCollateralAmount) {
            revert SCEngine__AmountShouldBeLessThanCollateral();
        }
        s_userCollateralAmounts[from][collateralToken] -= amount;
        emit CollateralRedeemed(from, to, collateralToken, amount);
        bool success = IERC20(collateralToken).transfer(to, amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function _getAccountInfo(address user) private view returns (uint256 totalSCMinted, uint256 totalCollateralValue) {
        totalSCMinted = s_SCMinted[user];
        totalCollateralValue = getAccountCollateralValue(user);
    }

    // Public/External view functions

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_userCollateralAmounts[user][token];
            totalCollateralValue += getUSDValue(token, amount);
        }
    }

    function healthFactor(address user) public view returns (uint256) {
        (uint256 totalSCMinted, uint256 totalCollateralValueInUsd) = _getAccountInfo(user);

        if (totalSCMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold =
            totalCollateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECESION;
        return collateralAdjustedForThreshold * PRECESION / totalSCMinted;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        address priceFeed = s_pricefeeds[token];
        AggregatorV3Interface priceFeedInterface = AggregatorV3Interface(priceFeed);
        (, int256 price,,,) = priceFeedInterface.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECESION;
    }

    function getTokenAmountFromUSD(address token, uint256 amountInUSD) public view returns (uint256) {
        AggregatorV3Interface priceFeedInterface = AggregatorV3Interface(s_pricefeeds[token]);
        (, int256 price,,,) = priceFeedInterface.latestRoundData();
        return (amountInUSD * PRECESION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInfo(address user) external view returns (uint256 totalSCMinted, uint256 totalCollateralValue) {
        return _getAccountInfo(user);
    }
}
