//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeploySC} from "../../script/DeploySC.s.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {Stablecoin} from "../../src/Stablecoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract SCEngineTest is Test {
    DeploySC deployer;
    Stablecoin dsc;
    SCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public user = makeAddr("user");

    uint256 amountCollateral = 10 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeploySC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,btcUsdPriceFeed, weth, wbtc,) = config.activeConfig();
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

        modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(amountCollateral, weth);
        vm.stopPrank();
        _;
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(SCEngine.SCEngine__TokenAddressesAndPriceFeedAddressesLengthsDontMatch.selector);
        new SCEngine(tokenAddresses, feedAddresses, address(dsc));
    }



    //////////////////
    // Price Tests  //
    //////////////////

    function testGetTokenAmountFromUsd() public {
   // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
   uint256 expectedWeth = 0.05 ether;
   uint256 amountWeth = dsce.getTokenAmountFromUSD(weth, 100 ether);
   assertEq(amountWeth, expectedWeth);
    }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 usdValue = dsce.getUSDValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    ////////////////////////
    // Deposit Collateral //
    ////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(0, weth);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
    ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
    vm.startPrank(user);
    vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__TokenNotAllowed.selector));
    dsce.depositCollateral(amountCollateral, address(randToken));
    vm.stopPrank();
}


    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInfo(user);
        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUSD(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    
}
