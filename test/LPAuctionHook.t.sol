// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPAuctionHook} from "../src/LPAuctionHook.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract LPAuctionHookTest is Test {
    using PoolIdLibrary for PoolKey;

    PoolManager manager;
    LPAuctionHook hook;
    PoolSwapTest swapRouter;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    MockERC20 token0;
    MockERC20 token1;
    PoolKey poolKey;
    PoolId poolId;

    address governor = makeAddr("governor");
    address lp1 = makeAddr("lp1");
    address arbA = makeAddr("arbitrageurA");
    address arbB = makeAddr("arbitrageurB");

    uint256 constant RESERVE_PRICE = 1 ether;
    uint256 constant COMMIT_WINDOW = 10;
    uint256 constant REVEAL_WINDOW = 10;
    uint256 constant CLAIM_WINDOW = 20;
    uint256 constant EPOCH_LENGTH =
        COMMIT_WINDOW + REVEAL_WINDOW + CLAIM_WINDOW;

    function setUp() public {
        manager = new PoolManager(address(this));
        swapRouter = new PoolSwapTest(manager);
        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);

        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
        );
        address hookAddress = address(flags ^ (0x4444 << 144)); // arbitrary high bits to dodge collisions, low bits preserved
        deployCodeTo(
            "LPAuctionHook.sol:LPAuctionHook",
            abi.encode(manager, governor),
            hookAddress
        );
        hook = LPAuctionHook(hookAddress);

        // Two mock tokens, sorted so currency0 < currency1 as v4 requires.
        MockERC20 a = new MockERC20("Token A", "A");
        MockERC20 b = new MockERC20("Token B", "B");
        (token0, token1) = address(a) < address(b) ? (a, b) : (b, a);

        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        poolId = poolKey.toId();

        manager.initialize(poolKey, TickMath.getSqrtPriceAtTick(0));

        // Fund the LP and approve the liquidity router.
        token0.mint(lp1, 1_000 ether);
        token1.mint(lp1, 1_000 ether);
        vm.startPrank(lp1);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);
        vm.stopPrank();

        vm.prank(governor);
        hook.setPoolParams(
            poolKey,
            LPAuctionHook.PoolAuctionParams({
                reservePrice: RESERVE_PRICE,
                epochLength: EPOCH_LENGTH,
                commitWindow: COMMIT_WINDOW,
                revealWindow: REVEAL_WINDOW,
                claimWindow: CLAIM_WINDOW,
                lpDistribution: 9000,
                noShowRefund: 700,
                settlementAsset: address(token0),
                configured: false // ignored on write, contract sets this true itself
            })
        );
    }

    function test_onlyGovernorCanSetParams() public {
        vm.expectRevert("not governor");
        hook.setPoolParams(
            poolKey,
            LPAuctionHook.PoolAuctionParams({
                reservePrice: 1,
                epochLength: 1,
                commitWindow: 0,
                revealWindow: 0,
                claimWindow: 1,
                lpDistribution: 0,
                noShowRefund: 0,
                settlementAsset: address(0),
                configured: false
            })
        );
    }

    function test_paramsRejectWindowsExceedingEpoch() public {
        vm.prank(governor);
        vm.expectRevert("windows exceed epoch");
        hook.setPoolParams(
            poolKey,
            LPAuctionHook.PoolAuctionParams({
                reservePrice: 1,
                epochLength: 5,
                commitWindow: 3,
                revealWindow: 3,
                claimWindow: 3,
                lpDistribution: 9000,
                noShowRefund: 700,
                settlementAsset: address(token0),
                configured: false
            })
        );
    }

    // Auction lifecycle — happy path
    function test_fullAuctionCycle_winnerClaimsSuccessfully() public {
        hook.startEpoch(poolKey);
        uint256 epoch = hook.currentEpoch(poolId);

        // Two arbitrageurs commit. B bids higher and should win.
        bytes32 saltA = keccak256("salt-a");
        bytes32 saltB = keccak256("salt-b");
        uint256 bidA = 1.5 ether;
        uint256 bidB = 2 ether;

        vm.prank(arbA);
        hook.commitBid(poolKey, keccak256(abi.encode(bidA, saltA)));
        vm.prank(arbB);
        hook.commitBid(poolKey, keccak256(abi.encode(bidB, saltB)));

        // Move into the reveal window.
        vm.warp(block.timestamp + COMMIT_WINDOW);

        vm.prank(arbA);
        hook.revealBid(poolKey, bidA, saltA);
        vm.prank(arbB);
        hook.revealBid(poolKey, bidB, saltB);

        (, , , , address winner, uint256 winningBid, , ) = hook.auctions(
            poolId,
            epoch
        );
        assertEq(winner, arbB, "highest bidder should be recorded winner");
        assertEq(winningBid, bidB);

        // Move into the claim window and have the winner swap.
        vm.warp(block.timestamp + REVEAL_WINDOW);

        token0.mint(arbB, 10 ether);
        vm.prank(arbB);
        token0.approve(address(swapRouter), type(uint256).max);

        vm.prank(arbB);
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ""
        );

        (, , , , , , , bool resolved) = hook.auctions(poolId, epoch);
        assertTrue(
            resolved,
            "auction should be marked resolved after winner claims"
        );
    }

    function test_nonWinnerCannotSwapDuringExclusiveWindow() public {
        hook.startEpoch(poolKey);

        bytes32 saltB = keccak256("salt-b");
        uint256 bidB = 2 ether;
        vm.prank(arbB);
        hook.commitBid(poolKey, keccak256(abi.encode(bidB, saltB)));
        vm.warp(block.timestamp + COMMIT_WINDOW);
        vm.prank(arbB);
        hook.revealBid(poolKey, bidB, saltB);
        vm.warp(block.timestamp + REVEAL_WINDOW);

        // arbA (not the winner) tries to swap during the exclusive window.
        token0.mint(arbA, 10 ether);
        vm.prank(arbA);
        token0.approve(address(swapRouter), type(uint256).max);

        vm.prank(arbA);
        vm.expectRevert();
        swapRouter.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ""
        );
    }

    //    Commit-reveal security properties

    function test_revealHijack_wrongSenderReverts() public {
        hook.startEpoch(poolKey);

        bytes32 salt = keccak256("salt-a");
        uint256 bid = 1.5 ether;
        vm.prank(arbA);
        hook.commitBid(poolKey, keccak256(abi.encode(bid, salt)));
        vm.warp(block.timestamp + COMMIT_WINDOW);

        // arbB tries to reveal arbA's committed bid by replaying the values —
        // this must fail because reveal is bound to the original committer's address.
        vm.prank(arbB);
        vm.expectRevert("no commit found");
        hook.revealBid(poolKey, bid, salt);
    }

    function test_revealBelowReservePriceReverts() public {
        hook.startEpoch(poolKey);

        bytes32 salt = keccak256("salt-a");
        uint256 lowBid = RESERVE_PRICE - 1;
        vm.prank(arbA);
        hook.commitBid(poolKey, keccak256(abi.encode(lowBid, salt)));
        vm.warp(block.timestamp + COMMIT_WINDOW);

        vm.prank(arbA);
        vm.expectRevert("below reserve price");
        hook.revealBid(poolKey, lowBid, salt);
    }
}
