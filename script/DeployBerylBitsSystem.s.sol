// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IBerylBitsB20Like} from "../src/interfaces/IBerylBitsB20Like.sol";
import {BerylBitsB20Curve} from "../src/BerylBitsB20Curve.sol";
import {BerylBitsB20Forge} from "../src/BerylBitsB20Forge.sol";
import {BerylBitsB20NFT} from "../src/BerylBitsB20NFT.sol";

contract DeployBerylBitsSystem is Script {
    function run() external returns (BerylBitsB20Curve curve, BerylBitsB20Forge forge, BerylBitsB20NFT nft) {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address tokenAddress = vm.envAddress("B20_TOKEN_ADDRESS");
        IBerylBitsB20Like token = IBerylBitsB20Like(tokenAddress);

        vm.startBroadcast();

        nft = new BerylBitsB20NFT(admin);
        forge = new BerylBitsB20Forge(token, nft, admin);
        curve = new BerylBitsB20Curve(token, admin, treasury);

        nft.grantRole(nft.FORGE_ROLE(), address(forge));

        vm.stopBroadcast();

        console.log("Curve", address(curve));
        console.log("Forge", address(forge));
        console.log("NFT", address(nft));
        console.log("Grant B20 MINT_ROLE and BURN_ROLE to Curve and Forge after deploy.");
    }
}
