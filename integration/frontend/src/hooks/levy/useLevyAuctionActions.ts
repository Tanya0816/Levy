import { useState } from 'react';
import { createWalletClient, custom, keccak256, encodeAbiParameters, parseEther, type Address, type Hex } from 'viem';
import { levyHookAbi } from '@/lib/levy/abi';
import { levyChain, LEVY_HOOK_ADDRESS } from '@/lib/levy/config';

type PoolKey = {
  currency0: Address;
  currency1: Address;
  fee: number;
  tickSpacing: number;
  hooks: Address;
};

declare global {
  interface Window {
    ethereum?: { request: (args: { method: string; params?: unknown[] }) => Promise<unknown> };
  }
}

function walletClient() {
  if (!window.ethereum) throw new Error('No injected wallet found');
  return createWalletClient({ chain: levyChain, transport: custom(window.ethereum) });
}

export function makeBidCommitment(bidWei: bigint, salt: Hex) {
  return keccak256(encodeAbiParameters([{ type: 'uint256' }, { type: 'bytes32' }], [bidWei, salt]));
}

export function useLevyAuctionActions() {
  const [pending, setPending] = useState(false);

  async function connect() {
    const client = walletClient();
    const [account] = await client.requestAddresses();
    return account;
  }

  async function startEpoch(key: PoolKey) {
    const client = walletClient();
    const [account] = await client.requestAddresses();
    setPending(true);
    try {
      return await client.writeContract({ address: LEVY_HOOK_ADDRESS, abi: levyHookAbi, functionName: 'startEpoch', args: [key], account });
    } finally { setPending(false); }
  }

  async function commitBid(key: PoolKey, bidEth: string, salt: Hex) {
    const client = walletClient();
    const [account] = await client.requestAddresses();
    const bidWei = parseEther(bidEth);
    const commitment = makeBidCommitment(bidWei, salt);
    setPending(true);
    try {
      return await client.writeContract({ address: LEVY_HOOK_ADDRESS, abi: levyHookAbi, functionName: 'commitBid', args: [key, commitment], account });
    } finally { setPending(false); }
  }

  async function revealBid(key: PoolKey, bidEth: string, salt: Hex) {
    const client = walletClient();
    const [account] = await client.requestAddresses();
    const bidWei = parseEther(bidEth);
    setPending(true);
    try {
      return await client.writeContract({ address: LEVY_HOOK_ADDRESS, abi: levyHookAbi, functionName: 'revealBid', args: [key, bidWei, salt], value: bidWei, account });
    } finally { setPending(false); }
  }

  async function claimPayout(key: PoolKey, epoch: bigint) {
    const client = walletClient();
    const [account] = await client.requestAddresses();
    setPending(true);
    try {
      return await client.writeContract({ address: LEVY_HOOK_ADDRESS, abi: levyHookAbi, functionName: 'claimPayout', args: [key, epoch], account });
    } finally { setPending(false); }
  }

  return { connect, startEpoch, commitBid, revealBid, claimPayout, pending };
}
