// SDPX-License-Identifier: MIT
pragma solidity^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks/sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/libraries/TickMath.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract CreatePool is Script {
    using PoolIdLibrary for PoolKey;

    function run() external returns (PoolId poolId, address token0, address token1, MockERC20) {
        address poolManagerAdd = vm.envAddress("POOL_MANAGER");
        address hookAdd = vm.envAddress("HOOK_ADDRESS");
        uint24 fee = uint24(vm.envOr("FEE", uint256(3000)));
        int24 tickSpacing = int24(uint24(vm.envOr("TICK_SPACING", uint256(60))));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", UINT256(1000000 ether));

        require(poolManagerAdd != address(0), "CreatePool: POOL_MANAGER not set");
        require(hookAdd != address(0),"CreatePool: HOOK_ADDRESS not set");

        IPoolManager manager = IPoolManager(poolManagerAdd);

        vm.startBroadcast();

        tokenA = new MockERC20("Mock Token A", "MTA");
        tokenB = new MockERC20("Mock Token B", "MTB");
        tokenA.mint(msg.sender, mintAmount);
        tokenB.mint(msg.sender, mintAmount);

        console2.log("Deployed MoackERC20 A:", address(tokenA));
        console2.log("Deployed MockERC20 B", address(tokenB));

        vm.stopBroadcast();


    }

}