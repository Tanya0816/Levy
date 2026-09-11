// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {ERC1155} from "v4-hooks-public/src/tokens/ERC1155.sol";

import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-hooks-public/types/BeforeSwapDelta.sol";
import {PoolKey} from "v4-hooks-public/src/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-hooks-public/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-hooks-public/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-hooks-public/types/PoolOperation.sol";
import {IPoolManager} from "v4-hooks-public/interfaces/IPoolManager.sol";
import {Hooks} from "v4-hooks-public/libraries/Hooks.sol";

// In thisnhook, Arbitrageurs bid via commit-reveal
// The winner claims the bidding prize by submitting their onw swap within a claim window.

contract LPAuctionHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct PoolAuctionParams {
        uint256 reservePrice;  //min acceptable winning bid
        uint256 epochLength;  // auction cycle per second
        uint256 commitWindow; // subset of epochlength (in seconds)
        uint256 revealWindow; //subset of epochlength, starts after commitwindow.
        uint256 claimWindow; // for winner to submit their swap within give timelimit after revealwindow to claim their prize.
        uint32 lpDistribution; // share successful winnning bid prize to LPs.
        uint32 noShowRefund; // for case when the winner does not claim prize within the given time.
        address settlementAsset; // winner got paid in after successfully claiming the prize.
        bool configured;
    }
    mapping(PoolId => PoolAuctionParams) public poolParams;

    address public governer;
    modifier onlyGoverner() {
        require(msg.sender == governer, "not a governer");
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
    mapping(PoolId => mapping(uint256  => mapping(address  => bytes32))) public commits;

    //mapping poolid with epoch and auction state
    mapping(PoolId => mapping(uint256 => Auction)) public auctions;

    //mapping poolid with current epoch number
    mapping(PoolId => uint256) public currentEpoch;

    // getting last epoch block using poolid
    mapping(PoolId => mapping(address => uint256)) public lastDepositBlock;

    //getting amount details to claim 
    mapping(PoolId => mapping(uint256 => mapping(address => uint256))) public claimableAmount;

    //Events

    event EpochStarted(PoolId indexed poolId, uint256 indexed epoch, uint256 epochStarted);
    event PoolParamsSet(PoolId indexed PoolId, PoolAuctionParams params);
    event BidCommited(PoolId indexed poolId, uint256 indexed epoch, address indexed bidder);
    event BidReveal(PoolId poolId, uint256 indexed epoh, address bidder, uint256 bidAmount);
    event WinnerClaimed(PoolId poolId, uint256 indexed epoch, address winner);
    event WinnerForfeiteed(PoolId poolId, uint256 indexed epoch, address winner, uint256 refund, uint256 toLPs);
    event LPDistributed(PoolId indexed poolId, uint256 indexed epoch, uint256 toLPs);


    constructor(IPoolManager _poolManager, address _governor) BaseHook(_poolManager) {
        governor = _governor;
    }

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

//   Governance Placeholder 
    function setPoolParams(PoolKey calldata key, PoolAuctionParams calldata params) external onlyGovernor {
        require(params.lpDistribution <= 10000 && params.noShowRefund <= 10000, "invalid");
        require(params.commitWindow + params.revealWindow + params.claimWindow <= params.epochLength, "Windows exceed epoch");
        PoolAuctionParams memory p = params;
        p.confirmed = true;
        poolParams[key.toId()] = p;
        emit PoolParamsSet(key.toId(), p);
    }

// After the bidding (i.e after revealBid function), only one swap is allowed in that window
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
    PoolId poolId = key.toId();
    uint256 epoch = currentEpoch[poolId];
    Auction storage a = auctions[poolId][epoch];

    bool windowActive = a.revealed && !a.resolved && block.timestamp >= a.revealDeadline && block.timestamp < a.claimDeadline;

    if ( windowActive) {
    require(sender == a.winner, "exclusive claim window: not the winner");
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
    ) external override returns (bytes4, BalanceDelta) {

        lastDepositBlock[key.toId()][sender]=block.number;
        return (this.afterAddLiquidity.selector, BalanceDelta({delta0: 0, delta1: 0}));

    }

// Starting epoch 
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

//  Commit phase in auction   
    function commitBid(PoolKey calldata key, bytes32 commitHash) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage  a = auctions[poolId][epoch];
        require(a.epochStart != 0, "no active epoch ");
        require(block.timestamp < a.commitDeadline, "commit window closed");

        commits[poolId][epoch][msg.sender] = commitHash;
        emit BidCommitted(poolId, epoch, msg.sender);
    }

// Reveal phase in auction - in this bidder reveals their actual bidding amount
    function revealBid(PoolKey calldata key, uint256 bidAmount, bytes32 salt) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];
        require(block.timestamp >= a.commitDeadline, "commit window is still open");
        require(block.timestamp < a.revealDeadline, "reveal window closed");

        bytes32 committed = commits[poolId][epoch][msg.sender];
        require(committed != bytes32(0), "no commit found");
        require(committed == keccak256(abi.encode(bidAmount, salt)), "invalid reveal");

        commits[poolId][epoch][msg.sender] = bytes32(0);

        PoolAuctionParams memory params = poolParams[poolId];
        require(bidAmount >= params.reservePrice, "below reserve price");

        if ( bidAmount > a.winningBid) {
            a.winningBid = bidAmount;
            a.winner = msg.sender;
        }
        a.revealed = true;

        emit BidReveal(poolId, epoch, msg.sender, bidA tytmount);

    }

    function settleForfeiture(PoolKey calldata key) external {
        PoolId poolId = key.toId();
        uint256 epoch = currentEpoch[poolId];
        Auction storage a = auctions[poolId][epoch];

        require(a.revealed && !a.resolved, "nothing to forfeit");
        require(block.timestamp >= a.ckaimDeadline, "claim window still open");

        a.resolved = true;
        _distributeBid(poolId, epoch,a.winningBid, true);

    }

    function _distributeBid(PoolId poolId, uint256 epoch, uint256 bidAmount, bool isForfeiture) internal {
        PoolAictionParams memory params = poolParams[poolId];
        Auction storsge a = auctions[poolId][epoch];

        uint256 toLPs;
        if (!isForfeiture) {
            uint256 refund = (bidAmount * params.noShowRefund) / 10000;
            toLPs = bidAmount - refund;
            emit WinnerForfeited(poolId, epoch,a.winner,refund,toLPs);
        } else {
            toLPs = (bidAmount * params.lpDistribution) / 10000;
        }

        claimable[poolId][epoch][address(0)] = toLPs;
        emit LPDistributed(poolId, epoch,toLPs);
    }



}
