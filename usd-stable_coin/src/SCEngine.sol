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
    error SCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error SCEngine__TransferFailed();
    error SCEngine__BreaksHealthFactor(uint256 healthFactor);
    error SCEngine__MintFailed();
    error SCEngine__AmountShouldBeGreaterThanCollateral();
    error SCEngine__BurnAmountExceedsSCMinted();
    // State variables

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECESION = 1e18;
    uint64 private constant LIQUIDATION_THRESHOLD = 20;
    uint64 private constant LIQUIDATION_PRECESION = 100;
    uint64 private constant MIN_HEALTH_FACTOR = 1;
    Stablecoin private immutable i_sc;

    mapping(address collateralToken => address priceFeed) private s_pricefeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_userCollateralAmounts;
    mapping(address user => uint256) private s_SCMinted;
    address[] private s_collateralTokens;

    // Events
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed collateralToken, uint256 indexed amount);

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
            revert SCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_pricefeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_sc = Stablecoin(_stablecoin);
    }

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

        function redeemCollateral(uint256 amount, address collateralToken) public moreThanZero(amount) isTokenAllowed(collateralToken) nonReentrant {
        uint256 userCollateralAmount = s_userCollateralAmounts[msg.sender][collateralToken];
        if (amount > userCollateralAmount) {
            revert SCEngine__AmountShouldBeGreaterThanCollateral();
        }
        s_userCollateralAmounts[msg.sender][collateralToken] -= amount;
        emit CollateralRedeemed(msg.sender, collateralToken, amount);
        bool success = IERC20(collateralToken).transfer(msg.sender, amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }
    

    function mintSC(uint256 amountSCToMint) public moreThanZero(amountSCToMint) nonReentrant {
        s_SCMinted[msg.sender] += amountSCToMint;
        _revertIfHealthFactorBelowThreshold(msg.sender);
        bool minted = i_sc.mint(msg.sender, amountSCToMint);
        if(!minted) {
            revert SCEngine__MintFailed();
        }
    }

    function burnSC(uint256 amount) external moreThanZero(amount) nonReentrant {
        uint256 userSCMinted = s_SCMinted[msg.sender];
        if (amount > userSCMinted) {
            revert SCEngine__BurnAmountExceedsSCMinted();
        }
        s_SCMinted[msg.sender] -= amount;
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
        i_sc.burn(amount);
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    // Internal functions

    function _revertIfHealthFactorBelowThreshold(address user) internal view {
        uint256 _healthFactor = healthFactor(user);
        if (_healthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__BreaksHealthFactor(_healthFactor);
        }
    }

    function healthFactor(address user) public view returns (uint256) {
        (uint256 totalSCMinted, uint256 totalCollateralValueInUsd) = _getAccountInfo(user);
        uint256 collateralAdjustedForThreshold =
            totalCollateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECESION;
        return collateralAdjustedForThreshold * PRECESION / totalSCMinted;
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

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        address priceFeed = s_pricefeeds[token];
        AggregatorV3Interface priceFeedInterface = AggregatorV3Interface(priceFeed);
        (, int256 price,,,) = priceFeedInterface.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECESION;
    }
    function getAccountInfo(address user) external view returns (uint256 totalSCMinted, uint256 totalCollateralValue) {
        return _getAccountInfo(user);
    }   
}
