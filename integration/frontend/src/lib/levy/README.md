# Levy live-data integration

Copy these files into the dashboard's `src/` tree.

Install `viem` and set:

VITE_LEVY_HOOK_ADDRESS=0x...
VITE_LEVY_RPC_URL=https://...
VITE_LEVY_CHAIN_ID=11155111
VITE_LEVY_CHAIN_NAME=Sepolia

The current contract accepts Uniswap v4 `PoolKey` values, so the UI must also know:
- currency0
- currency1
- fee
- tickSpacing
- hooks

This integration intentionally does not map reputation/sybil mock data to unrelated contract fields.
