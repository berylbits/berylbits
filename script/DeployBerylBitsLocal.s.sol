// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {BerylBitsB20Token} from "../src/BerylBitsB20Token.sol";
import {BerylBitsB20Curve} from "../src/BerylBitsB20Curve.sol";
import {BerylBitsB20Forge} from "../src/BerylBitsB20Forge.sol";
import {BerylBitsB20NFT} from "../src/BerylBitsB20NFT.sol";

contract DeployBerylBitsLocal is Script {
    function run() external returns (BerylBitsB20Token token, BerylBitsB20Curve curve, BerylBitsB20Forge forge, BerylBitsB20NFT nft) {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast();

        token = new BerylBitsB20Token(admin, 0);
        nft = new BerylBitsB20NFT(admin);
        forge = new BerylBitsB20Forge(token, nft, admin);
        curve = new BerylBitsB20Curve(token, admin, treasury);

        token.grantRole(token.MINT_ROLE(), address(curve));
        token.grantRole(token.BURN_ROLE(), address(curve));
        token.grantRole(token.MINT_ROLE(), address(forge));
        token.grantRole(token.BURN_ROLE(), address(forge));
        nft.grantRole(nft.FORGE_ROLE(), address(forge));

        vm.stopBroadcast();

        console.log("Token", address(token));
        console.log("Curve", address(curve));
        console.log("Forge", address(forge));
        console.log("NFT", address(nft));
    }
}
