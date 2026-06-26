// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BerylBitsB20NFTUpgradeable} from "../src/BerylBitsB20NFTUpgradeable.sol";

/// @notice Renders sample crystals (varied cuts + Mythic + Radiant) to ./previews
/// using the pure previewSVG helper. Run, do not broadcast.
contract PreviewBerylBitsArt is Script {
    BerylBitsB20NFTUpgradeable internal nft;

    function run() external {
        nft = new BerylBitsB20NFTUpgradeable();

        _write("01_hex.svg", _seedForCut(0), 700, "Hex / Standard");
        _write("02_shard.svg", _seedForCut(2), 701, "Shard / Standard");
        _write("03_needle.svg", _seedForCut(4), 702, "Needle / Standard");
        _write("04_royal.svg", _seedForCut(5), 703, "Royal / Standard");
        _write("05_mythic.svg", _seedForTier(true, false), 120, "Mythic (~1%)");
        _write("06_radiant.svg", _seedForTier(false, true), 7, "Radiant chase (~0.1%)");
    }

    function _write(string memory file, bytes32 seed, uint256 id, string memory label) internal {
        string memory svg = nft.previewSVG(seed, id);
        vm.writeFile(string.concat("./previews/", file), svg);
        // label kept for log readability
        label;
    }

    // Cut roll = keccak(seed,1) % 100; cutoffs [34,58,76,90,98,100] -> idx 0..5.
    function _seedForCut(uint256 cutIndex) internal pure returns (bytes32) {
        uint256[6] memory lo = [uint256(0), 34, 58, 76, 90, 98];
        uint256[6] memory hi = [uint256(34), 58, 76, 90, 98, 100];
        for (uint256 i = 1; i < 5_000_000; ++i) {
            bytes32 s = keccak256(abi.encode("CUT", i));
            uint256 roll = uint256(keccak256(abi.encode(s, uint256(1)))) % 100;
            if (roll >= lo[cutIndex] && roll < hi[cutIndex]) {
                // avoid accidental rare tiers for the "normal" samples
                if (uint256(keccak256(abi.encode(s, "MYTHIC"))) % 100 != 0 && uint256(keccak256(abi.encode(s, "RADIANT"))) % 1000 != 0) {
                    return s;
                }
            }
        }
        revert("no cut seed");
    }

    function _seedForTier(bool wantMythic, bool wantRadiant) internal pure returns (bytes32) {
        for (uint256 i = 1; i < 10_000_000; ++i) {
            bytes32 s = keccak256(abi.encode("TIER", i));
            bool m = uint256(keccak256(abi.encode(s, "MYTHIC"))) % 100 == 0;
            bool r = uint256(keccak256(abi.encode(s, "RADIANT"))) % 1000 == 0;
            if (wantRadiant && r) return s;
            if (wantMythic && m && !r) return s;
        }
        revert("no tier seed");
    }
}
