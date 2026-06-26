// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";
import {BerylBitsB20NFTUpgradeable} from "../src/BerylBitsB20NFTUpgradeable.sol";

contract DeployBerylBitsUpgradeableSystem is Script {
    function run()
        external
        returns (
            BerylBitsB20CurveUpgradeable curve,
            BerylBitsB20ForgeUpgradeable forge,
            BerylBitsB20NFTUpgradeable nft
        )
    {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address token = vm.envAddress("B20_TOKEN_ADDRESS");

        vm.startBroadcast();

        BerylBitsB20NFTUpgradeable nftImplementation = new BerylBitsB20NFTUpgradeable();
        ERC1967Proxy nftProxy =
            new ERC1967Proxy(address(nftImplementation), abi.encodeCall(BerylBitsB20NFTUpgradeable.initialize, (admin)));
        nft = BerylBitsB20NFTUpgradeable(address(nftProxy));

        BerylBitsB20ForgeUpgradeable forgeImplementation = new BerylBitsB20ForgeUpgradeable();
        ERC1967Proxy forgeProxy = new ERC1967Proxy(
            address(forgeImplementation),
            abi.encodeCall(BerylBitsB20ForgeUpgradeable.initialize, (token, address(nft), admin))
        );
        forge = BerylBitsB20ForgeUpgradeable(address(forgeProxy));

        BerylBitsB20CurveUpgradeable curveImplementation = new BerylBitsB20CurveUpgradeable();
        ERC1967Proxy curveProxy = new ERC1967Proxy(
            address(curveImplementation),
            abi.encodeCall(BerylBitsB20CurveUpgradeable.initialize, (token, admin, treasury))
        );
        curve = BerylBitsB20CurveUpgradeable(payable(address(curveProxy)));

        nft.grantRole(nft.FORGE_ROLE(), address(forge));
        forge.initializeV2(address(curve));

        vm.stopBroadcast();

        console.log("NFT implementation", address(nftImplementation));
        console.log("NFT proxy", address(nft));
        console.log("Forge implementation", address(forgeImplementation));
        console.log("Forge proxy", address(forge));
        console.log("Curve implementation", address(curveImplementation));
        console.log("Curve proxy", address(curve));
        console.log("Grant native B20 MINT_ROLE and BURN_ROLE to Curve and Forge after deploy.");
        console.log("Mint 25 off-curve team tokens to TEAM_ADDRESS after deploy.");
    }
}
