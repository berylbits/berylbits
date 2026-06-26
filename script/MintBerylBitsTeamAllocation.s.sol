// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IBerylBitsB20AdminLike} from "../src/interfaces/IBerylBitsB20AdminLike.sol";

/// @notice Mints the fixed team allocation directly to TEAM_ADDRESS.
contract MintBerylBitsTeamAllocation is Script {
    uint256 internal constant TEAM_ALLOCATION = 25 ether;

    function run() external {
        IBerylBitsB20AdminLike token = IBerylBitsB20AdminLike(vm.envAddress("B20_TOKEN_ADDRESS"));
        address team = vm.envAddress("TEAM_ADDRESS");
        address minter = vm.envAddress("DEPLOYER_ADDRESS");
        bytes32 mintRole = token.MINT_ROLE();

        vm.startBroadcast();
        token.grantRole(mintRole, minter);
        token.mint(team, TEAM_ALLOCATION);
        token.revokeRole(mintRole, minter);
        vm.stopBroadcast();

        console.log("Minted direct team allocation to", team);
        console.log("Team allocation", TEAM_ALLOCATION);
    }
}
