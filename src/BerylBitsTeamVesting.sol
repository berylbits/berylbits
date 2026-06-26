// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BerylBitsTeamVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable cliffDuration;
    uint256 public immutable linearDuration;
    uint256 public immutable totalAllocation;

    uint256 public released;

    error NothingToClaim();
    error InvalidSchedule();

    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 start_,
        uint256 cliffDuration_,
        uint256 linearDuration_,
        uint256 totalAllocation_
    ) {
        if (beneficiary_ == address(0) || cliffDuration_ == 0 || linearDuration_ == 0 || totalAllocation_ == 0) {
            revert InvalidSchedule();
        }

        token = token_;
        beneficiary = beneficiary_;
        start = start_;
        cliffDuration = cliffDuration_;
        linearDuration = linearDuration_;
        totalAllocation = totalAllocation_;
    }

    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 cliffEnd = start + cliffDuration;
        if (timestamp <= cliffEnd) return 0;

        uint256 elapsed = timestamp - cliffEnd;
        if (elapsed >= linearDuration) return totalAllocation;
        return (totalAllocation * elapsed) / linearDuration;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    function claim() external {
        uint256 amount = releasable();
        if (amount == 0) revert NothingToClaim();

        released += amount;
        token.safeTransfer(beneficiary, amount);
    }
}
