// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";

contract UpgradeBerylBitsV2 is Script {
    function run()
        external
        returns (
            BerylBitsB20CurveUpgradeable curveImplementation,
            BerylBitsB20ForgeUpgradeable forgeImplementation
        )
    {
        address curveProxy = vm.envAddress("CURVE_PROXY_ADDRESS");
        address forgeProxy = vm.envAddress("FORGE_PROXY_ADDRESS");

        vm.startBroadcast();

        curveImplementation = new BerylBitsB20CurveUpgradeable();
        BerylBitsB20CurveUpgradeable(payable(curveProxy)).upgradeToAndCall(address(curveImplementation), "");

        forgeImplementation = new BerylBitsB20ForgeUpgradeable();
        BerylBitsB20ForgeUpgradeable(forgeProxy).upgradeToAndCall(
            address(forgeImplementation),
            abi.encodeCall(BerylBitsB20ForgeUpgradeable.initializeV2, (curveProxy))
        );

        vm.stopBroadcast();

        console.log("Curve V2 implementation", address(curveImplementation));
        console.log("Forge V2 implementation", address(forgeImplementation));
    }
}
