// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IBerylBitsCurveSellLike {
    function sellTo(uint256 unitCount, uint256 minPayout, address payoutRecipient) external;
}
