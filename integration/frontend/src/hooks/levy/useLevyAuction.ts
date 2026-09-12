import { useQuery } from '@tanstack/react-query';
import { readContract } from 'viem/actions';
import { levyHookAbi } from '@/lib/levy/abi';
import { levyPublicClient } from '@/lib/levy/client';
import { LEVY_HOOK_ADDRESS } from '@/lib/levy/config';

export type AuctionView = {
  epoch: bigint;
  epochStart: bigint;
  commitDeadline: bigint;
  revealDeadline: bigint;
  claimDeadline: bigint;
  winner: `0x${string}`;
  winningBid: bigint;
  revealed: boolean;
  resolved: boolean;
  lpPool: bigint;
};

export function useLevyAuction(poolId: `0x${string}` | undefined) {
  return useQuery<AuctionView | null>({
    queryKey: ['levy', 'auction', poolId],
    enabled: Boolean(poolId && LEVY_HOOK_ADDRESS),
    refetchInterval: 3_000,
    queryFn: async () => {
      if (!poolId) return null;
      const epoch = await readContract(levyPublicClient, {
        address: LEVY_HOOK_ADDRESS,
        abi: levyHookAbi,
        functionName: 'currentEpoch',
        args: [poolId],
      });
      const auction = await readContract(levyPublicClient, {
        address: LEVY_HOOK_ADDRESS,
        abi: levyHookAbi,
        functionName: 'auctions',
        args: [poolId, epoch],
      });
      const lpPool = await readContract(levyPublicClient, {
        address: LEVY_HOOK_ADDRESS,
        abi: levyHookAbi,
        functionName: 'lpPool',
        args: [poolId, epoch],
      });
      return {
        epoch,
        epochStart: auction[0],
        commitDeadline: auction[1],
        revealDeadline: auction[2],
        claimDeadline: auction[3],
        winner: auction[4],
        winningBid: auction[5],
        revealed: auction[6],
        resolved: auction[7],
        lpPool,
      };
    },
  });
}
