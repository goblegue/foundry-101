//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Stablecoin} from "../../src/Stablecoin.sol";
import {SCEngine} from "../../src/SCEngine.sol";

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    Stablecoin stablecoin;
    SCEngine scEngine;

    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator wethPriceFeed;

    uint256 public numOfTimesMintIsCalled = 0;
    address[] public validAddresses;

    uint256 MAX_DEPOSIT_AMOUNT = type(uint96).max;

    constructor(Stablecoin _stablecoin, SCEngine _scEngine) {
        stablecoin = _stablecoin;
        scEngine = _scEngine;

        address[] memory collateralTokens = scEngine.getCollateralTokens();

        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        wethPriceFeed = MockV3Aggregator(scEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    // redeem Collateral

    //     function mintSC(uint256 amount,uint256 addressSeed) public {
    //     if(validAddresses.length == 0){
    //         return;
    //     }
    //     address sender = validAddresses[addressSeed % validAddresses.length];
    //     (uint256 totalSCMinted, uint256 totalCollateralValueInUsd) = scEngine.getAccountInfo(sender);
    //     int256 maxSCMintable = int256((totalCollateralValueInUsd/2) - totalSCMinted);
    //     console.log("maxSCMintable:\n");
    //     console.logInt(maxSCMintable);
    //     if(maxSCMintable < 0) return;
    //     amount = bound(amount, 0, uint(maxSCMintable));
    //     if(amount == 0) return;
    //     vm.startPrank(sender);
    //     scEngine.mintSC(amount);
    //     vm.stopPrank();
    //     numOfTimesMintIsCalled++;
    // }

    function depositCollateral(uint256 collateralSeed, uint256 amount) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amount = bound(amount, 1, MAX_DEPOSIT_AMOUNT);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amount);
        collateral.approve(address(scEngine), amount);
        scEngine.depositCollateral(address(collateral), amount);
        vm.stopPrank();
        bool alreadyExist = _validateIfAddressAlreadyExist(msg.sender);
        if (!alreadyExist) {
            validAddresses.push(msg.sender);
        }
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amount, uint256 addressSeed) public {
        if (validAddresses.length == 0) {
            return;
        }
        address sender = validAddresses[addressSeed % validAddresses.length];
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralRedeemable = scEngine.getCollateralBalanceOfUser(sender, address(collateral));
        console.log("maxCollateralRedeemable: %s", maxCollateralRedeemable);
        amount = bound(amount, 0, maxCollateralRedeemable);
        console.log("amount: %s", amount);
        uint256 healthfacter = scEngine.getHealthFactor(sender);
        console.log(healthfacter);
        if (amount == 0) return;
        vm.prank(sender);
        scEngine.redeemCollateral(address(collateral), amount);
        uint256 newHealthFactor = scEngine.getHealthFactor(sender);
        console.log(newHealthFactor);
    }

    // function updateCollateral(uint96 newPrice) public {
    //     int newPriceInt = int256(uint256(newPrice));
    //     wethPriceFeed.updateAnswer(newPriceInt);
    // }

    // Helper functions

    function _getCollateralFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    function _validateIfAddressAlreadyExist(address _address) private view returns (bool) {
        for (uint256 i = 0; i < validAddresses.length; i++) {
            if (validAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
