// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";
import {BerylBitsB20NFTUpgradeable} from "../src/BerylBitsB20NFTUpgradeable.sol";

contract ConfigureBerylBitsGovernance is Script {
    function run() external {
        address curve = vm.envAddress("CURVE_PROXY_ADDRESS");
        address forge = vm.envAddress("FORGE_PROXY_ADDRESS");
        address nft = vm.envAddress("NFT_PROXY_ADDRESS");
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        address timelock = vm.envAddress("TIMELOCK_ADDRESS");

        vm.startBroadcast();

        _configureCurve(BerylBitsB20CurveUpgradeable(payable(curve)), multisig, timelock);
        _configureForge(BerylBitsB20ForgeUpgradeable(forge), multisig, timelock);
        _configureNft(BerylBitsB20NFTUpgradeable(nft), multisig, timelock);

        vm.stopBroadcast();

        console.log("Configured app governance roles.");
    }

    function _configureCurve(BerylBitsB20CurveUpgradeable curve, address multisig, address timelock) internal {
        curve.grantRole(curve.PAUSE_ROLE(), multisig);
        curve.grantRole(curve.RESCUE_ROLE(), multisig);
        curve.grantRole(curve.UPGRADER_ROLE(), timelock);
    }

    function _configureForge(BerylBitsB20ForgeUpgradeable forge, address multisig, address timelock) internal {
        forge.grantRole(forge.PAUSE_ROLE(), multisig);
        forge.grantRole(forge.RESCUE_ROLE(), multisig);
        forge.grantRole(forge.UPGRADER_ROLE(), timelock);
    }

    function _configureNft(BerylBitsB20NFTUpgradeable nft, address multisig, address timelock) internal {
        nft.grantRole(nft.PAUSE_ROLE(), multisig);
        nft.grantRole(nft.RESCUE_ROLE(), multisig);
        nft.grantRole(nft.UPGRADER_ROLE(), timelock);
    }
}
