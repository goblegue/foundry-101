
// pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {DeploySC} from "../../script/DeploySC.s.sol";
// import {SCEngine} from "../../src/SCEngine.sol";
// import {Stablecoin} from "../../src/Stablecoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "../mocks/ERC20Mock.sol";

// contract SCEngineTest is Test {
//     DeploySC deployer;
//     Stablecoin dsc;
//     SCEngine dsce;
//     HelperConfig config;
//     address ethUSDPriceFeed;
//     address btcUSDPriceFeed;
//     address weth;
//     address wbtc;

//     address public user = makeAddr("user");

//     uint256 amountCollateral = 10 ether;
//     uint256 public constant STARTING_USER_BALANCE = 10 ether;

//     function setUp() public {
//         deployer = new DeploySC();
//         (dsc, dsce, config) = deployer.run();
//         (ethUSDPriceFeed,btcUSDPriceFeed, weth, wbtc,) = config.activeConfig();
//         ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
//         ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
//     }

//         modifier depositedCollateral() {
//         vm.startPrank(user);
//         ERC20Mock(weth).approve(address(dsce), amountCollateral);
//         dsce.depositCollateral(amountCollateral, weth);
//         vm.stopPrank();
//         _;
//     }

//     ///////////////////////
//     // Constructor Tests //
//     ///////////////////////
//     address[] public tokenAddresses;
//     address[] public feedAddresses;

//     function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
//         tokenAddresses.push(weth);
//         feedAddresses.push(ethUSDPriceFeed);
//         feedAddresses.push(btcUSDPriceFeed);

//         vm.expectRevert(SCEngine.SCEngine__TokenAddressesAndPriceFeedAddressesLengthsDontMatch.selector);
//         new SCEngine(tokenAddresses, feedAddresses, address(dsc));
//     }



//     //////////////////
//     // Price Tests  //
//     //////////////////

//     function testGetTokenAmountFromUSD() public {
//    // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
//    uint256 expectedWeth = 0.05 ether;
//    uint256 amountWeth = dsce.getTokenAmountFromUSD(weth, 100 ether);
//    assertEq(amountWeth, expectedWeth);
//     }

//     function testGetUSDValue() public {
//         uint256 ethAmount = 15e18;
//         // 15e18 ETH * $2000/ETH = $30,000e18
//         uint256 expectedUSD = 30000e18;
//         uint256 usdValue = dsce.getUSDValue(weth, ethAmount);
//         assertEq(usdValue, expectedUSD);
//     }

//     ////////////////////////
//     // Deposit Collateral //
//     ////////////////////////

//     function testRevertsIfCollateralZero() public {
//         vm.startPrank(user);
//         ERC20Mock(weth).approve(address(dsce), amountCollateral);

//         vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
//         dsce.depositCollateral(0, weth);
//         vm.stopPrank();
//     }

//     function testRevertsWithUnapprovedCollateral() public {
//     ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
//     vm.startPrank(user);
//     vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__TokenNotAllowed.selector));
//     dsce.depositCollateral(amountCollateral, address(randToken));
//     vm.stopPrank();
// }


//     function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
//         (uint256 totalSCMinted, uint256 collateralValueInUSD) = dsce.getAccountInfo(user);
//         uint256 expectedDepositedAmount = dsce.getTokenAmountFromUSD(weth, collateralValueInUSD);
//         assertEq(totalSCMinted, 0);
//         assertEq(expectedDepositedAmount, amountCollateral);
//     }

    
// }


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { DeploySC } from "../../script/DeploySC.s.sol";
import { SCEngine } from "../../src/SCEngine.sol";
import { Stablecoin } from "../../src/Stablecoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { MockMoreDebtDSC } from "../mocks/MockMoreDebtDSC.sol";
import { MockFailedMintDSC } from "../mocks/MockFailedMintDSC.sol";
import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
import { MockFailedTransfer } from "../mocks/MockFailedTransfer.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract SCEngineTest is StdCheats, Test {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
        // redeemFrom != redeemedTo, then it was liquidated

    SCEngine public dsce;
    Stablecoin public dsc;
    HelperConfig public helperConfig;

    address public ethUSDPriceFeed;
    address public btcUSDPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeploySC deployer = new DeploySC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUSDPriceFeed, btcUSDPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeConfig();
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        // Should we put our integration tests here?
        // else {
        //     user = vm.addr(deployerKey);
        //     ERC20Mock mockErc = new ERC20Mock("MOCK", "MOCK", user, 100e18);
        //     MockV3Aggregator aggregatorMock = new MockV3Aggregator(
        //         helperConfig.DECIMALS(),
        //         helperConfig.ETH_USD_PRICE()
        //     );
        //     vm.etch(weth, address(mockErc).code);
        //     vm.etch(wbtc, address(mockErc).code);
        //     vm.etch(ethUSDPriceFeed, address(aggregatorMock).code);
        //     vm.etch(btcUSDPriceFeed, address(aggregatorMock).code);
        // }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUSDPriceFeed);
        feedAddresses.push(btcUSDPriceFeed);

        vm.expectRevert(SCEngine.SCEngine__TokenAddressesAndPriceFeedAddressesLengthsDontMatch.selector);
        new SCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    //////////////////
    // Price Tests //
    //////////////////

    function testGetTokenAmountFromUSD() public {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = dsce.getTokenAmountFromUSD(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testGetUSDValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUSD = 30_000e18;
        uint256 usdValue = dsce.getUSDValue(weth, ethAmount);
        assertEq(usdValue, expectedUSD);
    }

    ///////////////////////////////////////
    // depositCollateral Tests //
    ///////////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFromFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockSC = new MockFailedTransferFrom();
        tokenAddresses = [address(mockSC)];
        feedAddresses = [ethUSDPriceFeed];
        vm.prank(owner);
        SCEngine mockSCe = new SCEngine(tokenAddresses, feedAddresses, address(mockSC));
        mockSC.mint(user, amountCollateral);

        vm.prank(owner);
        mockSC.transferOwnership(address(mockSCe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockSC)).approve(address(mockSCe), amountCollateral);
        // Act / Assert
        vm.expectRevert(SCEngine.SCEngine__TransferFailed.selector);
        mockSCe.depositCollateral(address(mockSC), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__TokenNotAllowed.selector, address(randToken)));
        dsce.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalSCMinted, uint256 collateralValueInUSD) = dsce.getAccountInfo(user);
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalSCMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // depositCollateralAndMintSC Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedSCBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUSDPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUSDValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedSC() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedSC {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // mintSC Tests //
    ///////////////////////////////////
    // This test needs it's own custom setup
    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintDSC mockSC = new MockFailedMintDSC();
        tokenAddresses = [weth];
        feedAddresses = [ethUSDPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SCEngine mockSCe = new SCEngine(tokenAddresses, feedAddresses, address(mockSC));
        mockSC.transferOwnership(address(mockSCe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockSCe), amountCollateral);

        vm.expectRevert(SCEngine.SCEngine__MintFailed.selector);
        mockSCe.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.mintSC(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price,,,) = MockV3Aggregator(ethUSDPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMint, dsce.getUSDValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintSC(amountToMint);
        vm.stopPrank();
    }

    function testCanMintSC() public depositedCollateral {
        vm.prank(user);
        dsce.mintSC(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnSC Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.burnSC(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnSC(1);
    }

    function testCanBurnSC() public depositedCollateralAndMintedSC {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnSC(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockSC = new MockFailedTransfer();
        tokenAddresses = [address(mockSC)];
        feedAddresses = [ethUSDPriceFeed];
        vm.prank(owner);
        SCEngine mockSCe = new SCEngine(tokenAddresses, feedAddresses, address(mockSC));
        mockSC.mint(user, amountCollateral);

        vm.prank(owner);
        mockSC.transferOwnership(address(mockSCe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockSC)).approve(address(mockSCe), amountCollateral);
        // Act / Assert
        mockSCe.depositCollateral(address(mockSC), amountCollateral);
        vm.expectRevert(SCEngine.SCEngine__TransferFailed.selector);
        mockSCe.redeemCollateral(address(mockSC), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        uint256 userBalance = ERC20Mock(weth).balanceOf(user);
        assertEq(userBalance, amountCollateral);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(dsce));
        emit CollateralRedeemed(user, user, weth, amountCollateral);
        vm.startPrank(user);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }
    ///////////////////////////////////
    // redeemCollateralForSC Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedSC {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateralAndBurnSC(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.redeemCollateralAndBurnSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedSC {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = dsce.getHealthFactor(user);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedSC {
        int256 ethUSDUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUSDPriceFeed).updateAnswer(ethUSDUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalSCMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtDSC mockSC = new MockMoreDebtDSC(ethUSDPriceFeed);
        tokenAddresses = [weth];
        feedAddresses = [ethUSDPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        SCEngine mockSCe = new SCEngine(tokenAddresses, feedAddresses, address(mockSC));
        mockSC.transferOwnership(address(mockSCe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockSCe), amountCollateral);
        mockSCe.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockSCe), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockSCe.depositCollateralAndMintSC(weth, collateralToCover, amountToMint);
        mockSC.approve(address(mockSCe), debtToCover);
        // Act
        int256 ethUSDUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUSDPriceFeed).updateAnswer(ethUSDUpdatedPrice);
        // Act/Assert
        vm.expectRevert(SCEngine.SCEngine__HealthFactorNotImproved.selector);
        mockSCe.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedSC {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);

        vm.expectRevert(SCEngine.SCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, user, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUSDUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUSDPriceFeed).updateAnswer(ethUSDUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(user);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, user, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dsce.getTokenAmountFromUSD(weth, amountToMint)
            + (dsce.getTokenAmountFromUSD(weth, amountToMint) / dsce.getLiquidationBonus());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = dsce.getTokenAmountFromUSD(weth, amountToMint)
            + (dsce.getTokenAmountFromUSD(weth, amountToMint) / dsce.getLiquidationBonus());

        uint256 usdAmountLiquidated = dsce.getUSDValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUSD = dsce.getUSDValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUSD) = dsce.getAccountInfo(user);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUSD, expectedUserCollateralValueInUSD);
        assertEq(userCollateralValueInUSD, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorSCMinted,) = dsce.getAccountInfo(liquidator);
        assertEq(liquidatorSCMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userSCMinted,) = dsce.getAccountInfo(user);
        assertEq(userSCMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = dsce.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUSDPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = dsce.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = dsce.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = dsce.getAccountInfo(user);
        uint256 expectedCollateralValue = dsce.getUSDValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = dsce.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = dsce.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = dsce.getUSDValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetSC() public {
        address dscAddress = dsce.getSC();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dsce.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    // How do we adjust our invariant tests for this?
    // function testInvariantBreaks() public depositedCollateralAndMintedSC {
    //     MockV3Aggregator(ethUSDPriceFeed).updateAnswer(0);

    //     uint256 totalSupply = dsc.totalSupply();
    //     uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(dsce));
    //     uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

    //     uint256 wethValue = dsce.getUSDValue(weth, wethDeposted);
    //     uint256 wbtcValue = dsce.getUSDValue(wbtc, wbtcDeposited);

    //     console.log("wethValue: %s", wethValue);
    //     console.log("wbtcValue: %s", wbtcValue);
    //     console.log("totalSupply: %s", totalSupply);

    //     assert(wethValue + wbtcValue >= totalSupply);
    // }
}
