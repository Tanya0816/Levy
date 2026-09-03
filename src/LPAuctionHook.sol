// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-hooks-public/types/Currency.sol";
import {PoolKey} from "v4-hooks-public/src/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-hooks-public/types/PoolId.sol";
import {BalanceDelta} from "v4-hooks-public/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-hooks-public/types/PoolOperation.sol";
import {IPoolManager} from "v4-hooks-public/interfaces/IPoolManager.sol";
import {Hooks} from "v4-hooks-public/libraries/Hooks.sol";

contract LPAuctionHook is BaseHook {

    mapping(PoolId => mapping(uint256 epoch => mapping(address bidder => bytes32 commitHash))) public commits;
    
    function getHookPermissions() 
    public
    pure
    override
    returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity:false,
            beforeSwap:true,
            afterSwap:false,
            beforeDenote:false,
            afterDenote:false,
            beforeSwapReturnDelta:false,  
            afterSwapReturnDelta:false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta:false

        });
    }
    function _beforeSwap() {

    }

    function _afterAddLiquidity() {

    }

    function commitBid() {
    }

    function revealBid() {}

    function startEpoch() {
    }

}
