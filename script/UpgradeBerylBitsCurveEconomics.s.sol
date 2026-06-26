// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";

/// @notice Deploys a new curve implementation and upgrades the existing proxy.
/// @dev Use for economics-only changes; forge and NFT proxies are intentionally untouched.
contract UpgradeBerylBitsCurveEconomics is Script {
    function run() external returns (BerylBitsB20CurveUpgradeable curveImplementation) {
        address curveProxy = vm.envAddress("CURVE_PROXY_ADDRESS");

        vm.startBroadcast();

        curveImplementation = new BerylBitsB20CurveUpgradeable();
        BerylBitsB20CurveUpgradeable(payable(curveProxy)).upgradeToAndCall(address(curveImplementation), "");

        vm.stopBroadcast();

        console.log("Curve economics implementation", address(curveImplementation));
        console.log("Curve proxy", curveProxy);
    }
}
