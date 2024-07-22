// //SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import {DeploySC} from "../../script/DeploySC.s.sol";
// import {SCEngine} from "../../src/SCEngine.sol";
// import {Stablecoin} from "../../src/Stablecoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantTest is StdInvariant, Test {
//     DeploySC deploySC;
//     SCEngine scEngine;
//     Stablecoin stablecoin;
//     HelperConfig helperConfig;

//     address weth;
//     address wbtc;

//     function setUp() external {
//         deploySC = new DeploySC();
//         (stablecoin, scEngine, helperConfig) = deploySC.run();
//         (,, weth, wbtc,) = helperConfig.activeConfig();

//         console.log("Stablecoin address: ", address(stablecoin));
//         targetContract(address(scEngine));
//     }

//     function invariant_protocolMustHaveMoreValueThanCollateral() public {
//         uint256 totalSupply = stablecoin.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(scEngine));
//         uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(scEngine));

//         uint256 wethValue = scEngine.getUSDValue(weth, totalWethDeposited);
//         uint256 wbtcValue = scEngine.getUSDValue(wbtc, totalWbtcDeposited);

//         assert(totalSupply < wethValue + wbtcValue);
//     }
// }
