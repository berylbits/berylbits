// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";

/// @notice Production B20 deployment script targeting the Base factory precompile.
/// @dev This script is intended for Base Sepolia/Mainnet broadcasting with --skip-simulation.
contract CreateBerylBitsB20Token is Script {
    uint256 internal constant MAX_SHARED_SUPPLY = 10_000 ether;

    function run() external returns (address token) {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        bytes32 salt = vm.envBytes32("B20_SALT");
        string memory contractUri = vm.envString("B20_CONTRACT_URI");

        bytes memory params = B20FactoryLib.encodeAssetCreateParams("Beryl Bits", "BBITS", admin, 18);
        bytes[] memory initCalls = new bytes[](7);
        initCalls[0] = B20FactoryLib.encodeUpdateSupplyCap(MAX_SHARED_SUPPLY);
        initCalls[1] = B20FactoryLib.encodeUpdateContractURI(contractUri);
        initCalls[2] = B20FactoryLib.encodeUpdateExtraMetadata("project", "Beryl Bits");
        initCalls[3] = B20FactoryLib.encodeUpdateExtraMetadata("primitive", "B20_TO_ONCHAIN_NFT_1_TO_1");
        initCalls[4] = B20FactoryLib.encodeUpdateExtraMetadata("network", "Base");
        initCalls[5] = B20FactoryLib.encodeUpdateExtraMetadata("policy_gating", "disabled_v1");
        initCalls[6] = B20FactoryLib.encodeUpdateExtraMetadata("website", contractUri);

        vm.startBroadcast();
        token = StdPrecompiles.B20_FACTORY.createB20(IB20Factory.B20Variant.ASSET, salt, params, initCalls);
        vm.stopBroadcast();

        console.log("Beryl Bits B20 deployed at", token);
    }
}
