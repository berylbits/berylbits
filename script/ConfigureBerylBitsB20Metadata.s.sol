// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IBerylBitsB20AdminLike} from "../src/interfaces/IBerylBitsB20AdminLike.sol";

/// @notice Applies B20 issuer metadata and governance role hardening to an existing Beryl Bits Base B20 asset.
/// @dev Requires the broadcaster to hold DEFAULT_ADMIN_ROLE and METADATA_ROLE where relevant.
contract ConfigureBerylBitsB20Metadata is Script {
    function run() external {
        IBerylBitsB20AdminLike token = IBerylBitsB20AdminLike(vm.envAddress("B20_TOKEN_ADDRESS"));
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        string memory contractUri = vm.envString("B20_CONTRACT_URI");
        string memory website = vm.envString("BERYL_BITS_WEBSITE");
        string memory docs = vm.envString("BERYL_BITS_DOCS_URI");
        string memory nft = _addressString(vm.envAddress("NFT_PROXY_ADDRESS"));
        string memory forge = _addressString(vm.envAddress("FORGE_PROXY_ADDRESS"));
        string memory curve = _addressString(vm.envAddress("CURVE_PROXY_ADDRESS"));
        string memory team = _addressString(vm.envAddress("TEAM_ADDRESS"));

        vm.startBroadcast();

        token.updateContractURI(contractUri);
        token.updateExtraMetadata("project", "Beryl Bits");
        token.updateExtraMetadata("primitive", "B20_TO_ONCHAIN_NFT_1_TO_1");
        token.updateExtraMetadata("network", "Base");
        token.updateExtraMetadata("policy_gating", "disabled_v1");
        token.updateExtraMetadata("website", website);
        token.updateExtraMetadata("docs", docs);
        token.updateExtraMetadata("nft_contract", nft);
        token.updateExtraMetadata("forge_contract", forge);
        token.updateExtraMetadata("curve_contract", curve);
        token.updateExtraMetadata("team_wallet", team);
        token.updateExtraMetadata("team_allocation", "25");
        token.updateExtraMetadata("team_sell_lock", "unlock_at_1000_public_units");

        token.grantRole(token.METADATA_ROLE(), multisig);
        token.grantRole(token.PAUSE_ROLE(), multisig);
        token.grantRole(token.UNPAUSE_ROLE(), multisig);

        vm.stopBroadcast();

        console.log("Configured B20 metadata and governance metadata/pause roles.");
    }

    function _addressString(address account) internal pure returns (string memory) {
        bytes20 value = bytes20(account);
        bytes16 symbols = "0123456789abcdef";
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 0; i < 20; ++i) {
            buffer[2 + i * 2] = symbols[uint8(value[i] >> 4)];
            buffer[3 + i * 2] = symbols[uint8(value[i] & 0x0f)];
        }
        return string(buffer);
    }
}
