import { useState } from 'react';
import type { Address } from 'viem';
import { AuctionCard } from './components/levy/AuctionCard';
import { LEVY_HOOK_ADDRESS, LEVY_RPC_URL } from './lib/levy/config';

const zero = '0x0000000000000000000000000000000000000000' as Address;
const poolId = (import.meta.env.VITE_LEVY_POOL_ID || '') as `0x${string}`;
const poolKey = {
 currency0: (import.meta.env.VITE_LEVY_CURRENCY0 || zero) as Address,
 currency1: (import.meta.env.VITE_LEVY_CURRENCY1 || zero) as Address,
 fee: Number(import.meta.env.VITE_LEVY_FEE || 3000),
 tickSpacing: Number(import.meta.env.VITE_LEVY_TICK_SPACING || 60),
 hooks: LEVY_HOOK_ADDRESS,
};

export function App(){
 const [connected,setConnected]=useState(false);
 return <main className="page"><header><div><div className="eyebrow">LEVY PROTOCOL</div><h1>LP-governed MEV auction</h1><p className="muted">Auction the right to capture the first arbitrage trade. Route the value back to LPs.</p></div><button className="connect" onClick={async()=>{if(!window.ethereum){alert('Install a wallet extension such as MetaMask.');return;} await window.ethereum.request({method:'eth_requestAccounts'});setConnected(true)}}>{connected?'Wallet connected':'Connect wallet'}</button></header>
 <div className="status"><span className={LEVY_HOOK_ADDRESS?'dot live':'dot'}></span>{LEVY_HOOK_ADDRESS?'Hook configured':'Hook address not configured'} · {LEVY_RPC_URL?'RPC configured':'RPC not configured'}</div>
 {poolId ? <AuctionCard poolId={poolId} poolKey={poolKey}/> : <section className="glass setup"><h2>One last setup</h2><p>Put your deployed hook and Uniswap v4 pool details in <code>.env</code>, then reload.</p><pre>{`VITE_LEVY_HOOK_ADDRESS=0x...\nVITE_LEVY_RPC_URL=https://...\nVITE_LEVY_POOL_ID=0x...\nVITE_LEVY_CURRENCY0=0x...\nVITE_LEVY_CURRENCY1=0x...\nVITE_LEVY_FEE=3000\nVITE_LEVY_TICK_SPACING=60\nVITE_LEVY_CHAIN_ID=11155111`}</pre><p className="muted small">The app now runs standalone; it does not depend on the missing original Lovable frontend files.</p></section>}
 <footer>Levy · ETHGlobal demo build</footer></main>
}
declare global { interface Window { ethereum?: { request(args:{method:string;params?:unknown[]}):Promise<unknown> } } }
