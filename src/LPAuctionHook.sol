// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "./BaseHook.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

// In thisnhook, Arbitrageurs bid via commit-reveal
// The winner claims the bidding prize by submitting their onw swap within a claim window.

contract LPAuctionHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    constructor(
        IPoolManager _poolManager,
        address _governor
    ) BaseHook(_poolManager) {
        governor = _governor;
    }

    struct PoolAuctionParams {
        uint256 reservePrice; //min acceptable winning bid
        uint256 epochLength; // auction cycle per second
        uint256 commitWindow; // subset of epochlength (in seconds)
        uint256 revealWindow; //subset of epochlength, starts after commitwindow.
        uint256 claimWindow; // for winner to submit their swap within give timelimit after revealwindow to claim their prize.
        uint32 lpDistribution; // share successful winnning bid prize to LPs.
        uint32 noShowRefund; // for case when the winner does not claim prize within the given time.
        address settlementAsset; // winner got paid in after successfully claiming the prize.
        bool configured;
    }
    mapping(PoolId => PoolAuctionParams) public poolParams;

    address public governor;
    modifier onlyGovernor() {
        require(msg.sender == governor, "not the governor");
        _;
    }

    // Auction state - handled by pool and epoch to ensure cycles neven collide.

    struct Auction {
        uint256 epochStart;
        uint256 commitDeadline;
        uint256 revealDeadline;
        uint256 claimDeadline;
        address winner;
        uint256 winningBid;
        bool revealed;
        bool resolved;
    }

    //poolId => epoch => bidder => commit hash
    mapping(PoolId => mapping(uint256 => mapping(address => bytes32)))
        public commits;

    //mapping poolid with epoch and auction state
    mapping(PoolId => mapping(uint256 => Auction)) public auctions;

    //mapping poolid with current epoch number
    mapping(PoolId => uint256) public currentEpoch;

    // getting last epoch block using poolid
    mapping(PoolId => mapping(address => uint256)) public lastDepositBlock;

    //getting amount details to claim
    mapping(PoolId => mapping(uint256 => mapping(address => uint256)))
        public claimableAmount;

    //Events

    event EpochStarted(
        PoolId indexed poolId,
        uint256 indexed epoch,
        uint256 epochStarted
    );
    event PoolParamsSet(PoolId indexed poolId, PoolAuctionParams params);
    event BidCommited(
        PoolId indexed poolId,
        uint256 indexed epoch,
        address indexed bidder
    );
    event BidReveal(
        PoolId poolId,
        uint256 indexed epoh,
        address bidder,
        uint256 bidAmount
    );
    event WinnerClaimed(PoolId poolId, uint256 indexed epoch, address winner);
    event WinnerForfeited(
        PoolId poolId,
        uint256 indexed epoch,
        address winner,
        uint256 refund,
        uint256 toLPs
    );
    event LPDistributed(
        PoolId indexed poolId,
        uint256 indexed epoch,
        uint256 toLPs
    );
    event LPClaimed(
        PoolId indexed poolId,
        uint256 indexed epoch,
        address claimer,
        uint256 amount
    );

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    //   Governance Placeholder
    function setPoolParams(
        PoolKey calldata key,
        PoolAuctionParams calldata params
    ) external onlyGovernor {
        require(
            params.lpDistribution <= 10000 && params.noShowRefund <= 10000,
            "invalid"
        );
        require(
            params.commitWindow + params.revealWindow + params.claimWindow <=
                params.epochLength,
            "Windows exceed epoch"
        );
        PoolAuctionParams memory p = params;
        p.configured = true;
        poolParams[key.toId()] = p;
        emit PoolParamsSet(key.toId(), p);
    }

    // After the bidding (i.e after revealBid function), only one swap is allowed in that window
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];

        bool windowActive = a.revealed &&
            !a.resolved &&
            block.timestamp >= a.revealDeadline &&
            block.timestamp < a.claimDeadline;

        if (windowActive) {
            require(
                sender == a.winner,
                "exclusive claim window: not the winner"
            );
            a.resolved = true;
            _distributeBid(poolId, epoch, a.winningBid, false);
            emit WinnerClaimed(poolId, epoch, a.winner);
        }
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // Anti-JIT snapshot stamped whenever liquidity is added.
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) external returns (bytes4, BalanceDelta) {
        lastDepositBlock[key.toId()][sender] = block.number;
        return (
            BaseHook.afterAddLiquidity.selector,
            BalanceDeltaLibrary.ZERO_DELTA
        );
    }

    // Starting epoch
    function startEpoch(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        PoolAuctionParams memory params = poolParams[poolId];
        require(params.configured, "pool is not configured");

        uint256 epoch = currentEpoch[poolId];
        Auction storage prev = auctions[poolId][epoch];
        require(
            epoch == 0 || block.timestamp >= prev.claimDeadline,
            "previous epoch is still active"
        );
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

    //  Commit phase in auction
    function commitBid(PoolKey calldata key, bytes32 commitHash) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];
        require(a.epochStart != 0, "no active epoch ");
        require(block.timestamp < a.commitDeadline, "commit window closed");

        commits[poolId][epoch][msg.sender] = commitHash;
        emit BidCommited(poolId, epoch, msg.sender);
    }

    // Reveal phase in auction - in this bidder reveals their actual bidding amount
    function revealBid(
        PoolKey calldata key,
        uint256 bidAmount,
        bytes32 salt
    ) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];
        require(
            block.timestamp >= a.commitDeadline,
            "commit window is still open"
        );
        require(block.timestamp < a.revealDeadline, "reveal window closed");

        bytes32 committed = commits[poolId][epoch][msg.sender];
        require(committed != bytes32(0), "no commit found");
        require(
            committed == keccak256(abi.encode(bidAmount, salt)),
            "invalid reveal"
        );

        commits[poolId][epoch][msg.sender] = bytes32(0);

        PoolAuctionParams memory params = poolParams[poolId];
        require(bidAmount >= params.reservePrice, "below reserve price");

        if (bidAmount > a.winningBid) {
            a.winningBid = bidAmount;
            a.winner = msg.sender;
        }
        a.revealed = true;

        emit BidReveal(poolId, epoch, msg.sender, bidAmount);
    }

    function settleForfeiture(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];

        require(a.revealed && !a.resolved, "nothing to forfeit");
        require(block.timestamp >= a.claimDeadline, "claim window still open");

        a.resolved = true;
        _distributeBid(poolId, epoch, a.winningBid, true);
    }

    function _distributeBid(
        PoolId poolId,
        uint256 epoch,
        uint256 bidAmount,
        bool isForfeiture
    ) internal {
        PoolAuctionParams memory params = poolParams[poolId];
        Auction storage a = auctions[poolId][epoch];

        uint256 toLPs;
        if (!isForfeiture) {
            uint256 refund = (bidAmount * params.noShowRefund) / 10000;
            toLPs = bidAmount - refund;
            emit WinnerForfeited(poolId, epoch, a.winner, refund, toLPs);
        } else {
            toLPs = (bidAmount * params.lpDistribution) / 10000;
        }

        claimableAmount[poolId][epoch][address(0)] = toLPs;
        emit LPDistributed(poolId, epoch, toLPs);
    }

    function claimPayout(PoolKey calldata key, uint256 epoch) external {
        PoolId poolId = key.toId();
        Auction storage a = auctions[poolId][epoch];

        require(a.epochStart != 0, "invalid epoch");
        require(lastDepositBlock[poolId][msg.sender] != 0, "never deposited");
        require(
            lastDepositBlock[poolId][msg.sender] <
                _epochStartBlock(poolId, epoch),
            "not eligible, epoch already started"
        );
        require(
            claimableAmount[poolId][epoch][msg.sender] == 0,
            "already claimed"
        );

        uint256 amount = claimableAmount[poolId][epoch][address(0)];
        require(amount > 0, "nothing to claim");

        claimableAmount[poolId][epoch][msg.sender] = amount;
        emit LPClaimed(poolId, epoch, msg.sender, amount);
    }

    function _epochStartBlock(
        PoolId poolId,
        uint256 epoch
    ) internal view returns (uint256) {
        return auctions[poolId][epoch].epochStart;
    }
}
