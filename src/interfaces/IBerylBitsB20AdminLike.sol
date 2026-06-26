// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IBerylBitsB20Like} from "./IBerylBitsB20Like.sol";

interface IBerylBitsB20AdminLike is IBerylBitsB20Like {
    function MINT_ROLE() external view returns (bytes32);
    function BURN_ROLE() external view returns (bytes32);
    function PAUSE_ROLE() external view returns (bytes32);
    function UNPAUSE_ROLE() external view returns (bytes32);
    function METADATA_ROLE() external view returns (bytes32);
    function OPERATOR_ROLE() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function updateSupplyCap(uint256 newSupplyCap) external;
    function updateContractURI(string calldata newURI) external;
    function updateExtraMetadata(string calldata key, string calldata value) external;
}
