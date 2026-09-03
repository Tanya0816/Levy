// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {ERC1155} from "v4-hooks-public/src/tokens/ERC1155.sol";

import {Currency} from "v4-hooks-public/types/Currency.sol";
import {PoolKey} from "v4-hooks-public/src/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-hooks-public/types/PoolId.sol";
import {BalanceDelta} from "v4-hooks-public/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-hooks-public/types/PoolOperation.sol";
import {IPoolManager} from "v4-hooks-public/interfaces/IPoolManager.sol";
import {Hooks} from "v4-hooks-public/libraries/Hooks.sol";

contract LPAuctionHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct PoolAuctionParams {
        uint256 reservePrice;  //min acceptable winning bid
        uint256 epochLength;  // auction cycle per second
        uint256 commitWindow;
        uint256 revealWindow;
        uint256 claimWindow;
        uint32 lpDistribution;
    }
    mapping(PoolId => PoolAuctionParams) public poolParams;

    address public governer;
    modifier onlyGoverner() {
        require(msg.sender == governer, "not a governer");
        _;
    }

    struct Auction {
        uint256 epochStart;
        uint256 commitDeadline;
        uint256 revealDeadline;
        uint256 claimDeadline;
        address winner;
        uint256 winningBid;
        bool revealed;
    }

    mapping(PoolId => mapping(uint256  => mapping(address  => bytes32))) public commits;

    event EpochStarted(PoolId indexed poolId, uint256 indexed epoch, uint256 epochStarted);
    event PoolParamsSet(PoolId indexed PoolId, POolAuctionParams params);
    
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
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {

    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {

        lastDepostiBlock[key.toId()][sender]=block.number;
        return (this.afterAddLiquidity.selector, BalanceDelta({delta0: 0, delta1: 0}));

    }

    function commitBid() {
    }

    function revealBid() {

    }

    function startEpoch(PoolKey calldata key) external {

        PoolAuctionParams memory params = poolParams[key.toId()];
        require(params.configured, "pool is not configured");

        uint256 epoch = currentEpoch[poolId];
        Auction storage prev = auctions[poolId][epoch];
        require(epoch == 0 || block.timestamp >= prev.claimDeadline, "previous epoch is still active");
        uint256 newEpoch = (epoch == 0 && prev.epochStart == 0) ? 0 : epoch + 1;
        if (epoch != 0 || prev.epochStart != 0) {
            currentEpoch[poolId] = newEpoch;
        }
        uint256 e = currentEpoch[poolId];

        Auction storage a = auctions[poolId][e];
        a.epochStart = block.timestamp;
        a.commitDeadline = block.timestamp + params.commitWindow;
        a.revealDeadline = a.commitDeadline + params.revealWindow;
        a.claimDeadline = a.revealDeadline + params.claimWindow;

        emit EpochStarted(poolId, e, a.epochStart);

    }

}
