// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";

/// @notice Deploys a fresh 8-band curve proxy and re-points the forge to it.
/// @dev The 8-band change resizes fixed storage arrays, so the existing curve
/// proxy cannot be upgraded in place; a new proxy is required. B20 mint/burn
/// role grant/revoke (old -> new curve) is handled separately via cast.
contract RedeployBerylBitsCurve8Bands is Script {
    function run() external returns (BerylBitsB20CurveUpgradeable curve) {
        address token = vm.envAddress("B20_TOKEN_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address forgeProxy = vm.envAddress("FORGE_PROXY_ADDRESS");
        address teamWallet = vm.envAddress("TEAM_ADDRESS");
        uint256 unlockUnits = vm.envUint("TEAM_SELL_UNLOCK_UNITS");

        vm.startBroadcast();

        BerylBitsB20CurveUpgradeable impl = new BerylBitsB20CurveUpgradeable();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(BerylBitsB20CurveUpgradeable.initialize, (token, admin, treasury))
        );
        curve = BerylBitsB20CurveUpgradeable(payable(address(proxy)));

        // Re-point forge's curve so redeemAndSell uses the new curve.
        BerylBitsB20ForgeUpgradeable(forgeProxy).setCurve(address(curve));

        // Enable the team sell lock on the new curve.
        curve.setTeamSellLock(teamWallet, unlockUnits);

        vm.stopBroadcast();

        console.log("New 8-band curve implementation", address(impl));
        console.log("New 8-band curve proxy", address(curve));
        console.log("Forge re-pointed to new curve");
        console.log("Team sell unlock units", curve.teamSellUnlockUnits());
        console.log("NEXT: grant B20 MINT_ROLE/BURN_ROLE to new curve, revoke from old curve.");
    }
}
