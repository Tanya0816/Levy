// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPAuctionHook} from "../src/LPAuctionHook.sol";
import {HookMiner} from "./HookMiner.sol";

contract DeployLPHook is Script {
    address constant CREATE2_DEPLOYER =
        0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external returns (LPAuctionHook hook, IPoolManager manager) {
        address governor = vm.envOr("GOVERNOR", msg.sender);
        address existingManager = vm.envOr("POOL_MANAGER", address(0));

        vm.startBroadcast();

        if (existingManager == address(0)) {
            manager = new PoolManager(msg.sender);
            console2.log("Deployed new PoolManager:", address(manager));
        } else {
            manager = IPoolManager(existingManager);
            console2.log("Using external PoolManager:", address(manager));
        }

        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
        );
        bytes memory constructorArgs = abi.encode(manager, governor);
        (address predictedAddress, bytes32 salt) = mineHookAddress(
            CREATE2_DEPLOYER,
            flags,
            constructorArgs
        );
        hook = new LPAuctionHook{salt: salt}(manager, governor);
        require(
            address(hook) == predictedAddress,
            "DeployLPHook: mined address mismatch"
        );

        console2.log("Deployed LPAuctionHook: ", address(hook));
        console2.log("Governor:", governor);
        console2.log("Salt used:", vm.toString(salt));

        vm.stopBroadcast();
    }

    function mineHookAddress(
        address deployer,
        uint160 flags,
        bytes memory constructorArgs
    ) internal view returns (address predictedAddress, bytes32 salt) {
        return
            HookMiner.find(
                deployer,
                flags,
                type(LPAuctionHook).creationCode,
                constructorArgs
            );
    }
}
