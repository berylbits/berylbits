// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IBerylBitsB20AdminLike} from "../src/interfaces/IBerylBitsB20AdminLike.sol";

/// @notice Grants native B20 MINT_ROLE and BURN_ROLE to the Curve and Forge proxies.
/// @dev Must run after DeployBerylBitsUpgradeableSystem and before any curve buy/sell or forge/redeem.
///      Requires the broadcaster to hold DEFAULT_ADMIN_ROLE on the B20 asset.
contract GrantBerylBitsB20Roles is Script {
    function run() external {
        IBerylBitsB20AdminLike token = IBerylBitsB20AdminLike(vm.envAddress("B20_TOKEN_ADDRESS"));
        address curve = vm.envAddress("CURVE_PROXY_ADDRESS");
        address forge = vm.envAddress("FORGE_PROXY_ADDRESS");

        bytes32 mintRole = token.MINT_ROLE();
        bytes32 burnRole = token.BURN_ROLE();

        vm.startBroadcast();

        // Curve mints on buy and burns on sell.
        token.grantRole(mintRole, curve);
        token.grantRole(burnRole, curve);

        // Forge burns the token on forge and mints it back on redeem.
        token.grantRole(mintRole, forge);
        token.grantRole(burnRole, forge);

        vm.stopBroadcast();

        console.log("Granted MINT_ROLE + BURN_ROLE to Curve", curve);
        console.log("Granted MINT_ROLE + BURN_ROLE to Forge", forge);
    }
}
