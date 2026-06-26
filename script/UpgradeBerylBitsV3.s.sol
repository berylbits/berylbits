// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";

/// @notice V3 upgrade: ships the team sell lock on the curve and removes
/// forgeWithPermit from the forge. Then configures the team sell lock so the
/// team wallet cannot pull ETH out of the curve until public demand reaches
/// `TEAM_SELL_UNLOCK_UNITS`.
/// @dev No reinitializer is needed. The new curve storage (`teamWallet`,
/// `teamSellUnlockUnits`) defaults to zero/unset, leaving the lock disabled
/// until `setTeamSellLock` is called below. The forge keeps its existing
/// `curve` wiring from initializeV2.
contract UpgradeBerylBitsV3 is Script {
    function run()
        external
        returns (
            BerylBitsB20CurveUpgradeable curveImplementation,
            BerylBitsB20ForgeUpgradeable forgeImplementation
        )
    {
        address curveProxy = vm.envAddress("CURVE_PROXY_ADDRESS");
        address forgeProxy = vm.envAddress("FORGE_PROXY_ADDRESS");
        address teamWallet = vm.envAddress("TEAM_ADDRESS");
        uint256 unlockUnits = vm.envUint("TEAM_SELL_UNLOCK_UNITS");

        vm.startBroadcast();

        curveImplementation = new BerylBitsB20CurveUpgradeable();
        BerylBitsB20CurveUpgradeable curve = BerylBitsB20CurveUpgradeable(payable(curveProxy));
        curve.upgradeToAndCall(address(curveImplementation), "");

        forgeImplementation = new BerylBitsB20ForgeUpgradeable();
        BerylBitsB20ForgeUpgradeable(forgeProxy).upgradeToAndCall(address(forgeImplementation), "");

        curve.setTeamSellLock(teamWallet, unlockUnits);

        vm.stopBroadcast();

        console.log("Curve V3 implementation", address(curveImplementation));
        console.log("Forge V3 implementation", address(forgeImplementation));
        console.log("Team sell lock wallet", curve.teamWallet());
        console.log("Team sell unlock units", curve.teamSellUnlockUnits());
    }
}
