import { createPublicClient, http } from 'viem';
import { levyChain } from './config';

export const levyPublicClient = createPublicClient({
  chain: levyChain,
  transport: http(
    import.meta.env.VITE_RPC_URL || "https://ethereum-sepolia-rpc.publicnode.com"
  ),
});