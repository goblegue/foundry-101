//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import{Test} from "forge-std/Test.sol";
import {Stablecoin} from "../../src/Stablecoin.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {DeploySC} from "../../script/DeploySC.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract SCEngineTest is Test{
    DeploySC deploySC;
    Stablecoin sc;
    SCEngine scEngine;
    HelperConfig hc;
    address address_weth; 
    ERC20Mock weth;



    address public user = makeAddr("user");

    function setUp() public {
        deploySC = new DeploySC();
        (sc, scEngine,hc) = deploySC.run();
        (,,address_weth,,)= hc.activeConfig();

        weth = ERC20Mock(address_weth);
        // Mint tokens to user
        weth.mint(user, 1000e18);
        vm.deal(user, 1e18); // provide some ETH for gas fees
    }

    function testMoreThanZeroModifier() public {
        vm.startPrank(user);
        vm.expectRevert(SCEngine.SCEngine__NeedsMoreThanZero.selector);
        scEngine.depositCollateral(0, address(weth));
        vm.stopPrank();
    }

    function testIsTokenAllowedModifier() public {
        vm.startPrank(user);
        ERC20Mock notAllowedToken = new ERC20Mock("Not Allowed Token", "NAT",user, 18);
        vm.expectRevert(SCEngine.SCEngine__TokenNotAllowed.selector);
        scEngine.depositCollateral(1e18, address(notAllowedToken));
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));
        assertEq(weth.balanceOf(address(scEngine)), 500e18);
        assertEq(scEngine.getAccountCollateralValue(user), scEngine.getUSDValue(address(weth), 500e18));
        vm.stopPrank();
    }

    function testMintSC() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));
        
        uint256 amountToMint = 100e18;
        scEngine.mintSC(amountToMint);

        assertEq(sc.balanceOf(user), amountToMint);
        assertEq(scEngine.getAccountCollateralValue(user), scEngine.getUSDValue(address(weth), 500e18));
        vm.stopPrank();
    }

    function testRevertIfHealthFactorBelowThreshold() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));
        
        uint256 amountToMint = 1000e18; // This should cause a revert due to low health factor
        vm.expectRevert(abi.encodeWithSelector(SCEngine.SCEngine__BreaksHealthFactor.selector, scEngine.healthFactor(user)));
        scEngine.mintSC(amountToMint);
        vm.stopPrank();
    }

    function testHealthFactor() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));

        uint256 _healthFactor = scEngine.healthFactor(user);
        assert(_healthFactor > 0);
        vm.stopPrank();
    }

    function testGetAccountInfo() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));

        (uint256 totalSCMinted, uint256 totalCollateralValue) = scEngine.getAccountInfo(user);
        assertEq(totalSCMinted, 0);
        assertEq(totalCollateralValue, scEngine.getUSDValue(address(weth), 500e18));
        vm.stopPrank();
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        weth.approve(address(scEngine), 500e18);
        scEngine.depositCollateral(500e18, address(weth));

        uint256 collateralValue = scEngine.getAccountCollateralValue(user);
        assertEq(collateralValue, scEngine.getUSDValue(address(weth), 500e18));
        vm.stopPrank();
    }

    function testGetUSDValue() public {
        uint256 amount = 500e18;
        uint256 usdValue = scEngine.getUSDValue(address(weth), amount);
        assertEq(usdValue, 1000000e18); // 500 WETH * $2000/WETH
    }
}
