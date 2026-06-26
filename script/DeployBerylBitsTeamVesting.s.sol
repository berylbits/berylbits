// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BerylBitsTeamVesting} from "../src/BerylBitsTeamVesting.sol";

/// @notice Legacy testnet vesting helper.
/// @dev Current mainnet plan does not deploy vesting. Use MintBerylBitsTeamAllocation.s.sol instead.
contract DeployBerylBitsTeamVesting is Script {
    uint256 internal constant TEAM_SUPPLY = 25 ether;
    uint256 internal constant CLIFF_DURATION = 180 days;
    uint256 internal constant LINEAR_DURATION = 540 days;

    function run() external returns (BerylBitsTeamVesting vesting) {
        address token = vm.envAddress("B20_TOKEN_ADDRESS");
        address beneficiary = vm.envAddress("TEAM_ADDRESS");
        uint256 start = vm.envOr("VESTING_START_TIMESTAMP", block.timestamp);

        vm.startBroadcast();
        vesting = new BerylBitsTeamVesting(
            IERC20(token),
            beneficiary,
            start,
            CLIFF_DURATION,
            LINEAR_DURATION,
            TEAM_SUPPLY
        );
        vm.stopBroadcast();

        console.log("Legacy team vesting", address(vesting));
        console.log("Beneficiary", beneficiary);
        console.log("Current mainnet plan skips this script and direct-mints 25 team tokens to TEAM_ADDRESS.");
    }
}
