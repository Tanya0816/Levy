import type { Address } from 'viem';

export const LEVY_HOOK_ADDRESS = (import.meta.env.VITE_LEVY_HOOK_ADDRESS ?? '') as Address;
export const LEVY_RPC_URL = import.meta.env.VITE_LEVY_RPC_URL ?? '';
export const LEVY_CHAIN_ID = Number(import.meta.env.VITE_LEVY_CHAIN_ID ?? 11155111);

export const levyChain = {
  id: LEVY_CHAIN_ID,
  name: import.meta.env.VITE_LEVY_CHAIN_NAME ?? 'Levy Testnet',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [LEVY_RPC_URL] } },
} as const;
