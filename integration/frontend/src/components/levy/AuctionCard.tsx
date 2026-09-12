import { useMemo, useState } from 'react';
import type { Address, Hex } from 'viem';
import { GlassCard, CardHeading } from './GlassCard';
import { useLevyAuction } from '@/hooks/levy/useLevyAuction';
import { useLevyAuctionActions } from '@/hooks/levy/useLevyAuctionActions';

export type AuctionPoolKey = {
  currency0: Address;
  currency1: Address;
  fee: number;
  tickSpacing: number;
  hooks: Address;
};

function shortAddress(value: string) {
  return value.length > 12 ? `${value.slice(0, 6)}…${value.slice(-4)}` : value;
}

function phase(now: number, auction: NonNullable<ReturnType<typeof useLevyAuction>['data']>) {
  if (auction.resolved) return 'Settled';
  if (now < Number(auction.commitDeadline) * 1000) return 'Commit';
  if (now < Number(auction.revealDeadline) * 1000) return 'Reveal';
  if (now < Number(auction.claimDeadline) * 1000) return 'Claim';
  return 'Forfeitable';
}

export function AuctionCard({ poolId, poolKey }: { poolId: `0x${string}`; poolKey: AuctionPoolKey }) {
  const { data, isPending } = useLevyAuction(poolId);
  const actions = useLevyAuctionActions();
  const [bid, setBid] = useState('0.01');
  const [salt, setSalt] = useState<Hex>(() => `0x${crypto.getRandomValues(new Uint8Array(32)).reduce((s, b) => s + b.toString(16).padStart(2, '0'), '')}` as Hex);
  const now = Date.now();
  const currentPhase = data ? phase(now, data) : 'Loading';
  const timeLeft = useMemo(() => {
    if (!data) return 0;
    const end = currentPhase === 'Commit' ? data.commitDeadline : currentPhase === 'Reveal' ? data.revealDeadline : data.claimDeadline;
    return Math.max(0, Number(end) * 1000 - now);
  }, [data, currentPhase, now]);

  const seconds = Math.floor(timeLeft / 1000);
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;

  return (
    <GlassCard padding="md" tone="accent">
      <CardHeading title="MEV auction" subtitle="LP-governed first-trade rights" action={<span className="phase">{currentPhase}</span>} />
      {isPending || !data ? (
        <div className="loading">Loading live auction…</div>
      ) : (
        <div className="auction-grid">
          <div className="metrics">
            <Metric label="Epoch" value={`#${data.epoch.toString()}`} />
            <Metric label="Highest bid" value={`${Number(data.winningBid) / 1e18} ETH`} />
            <Metric label="Winner" value={data.winner === '0x0000000000000000000000000000000000000000' ? '—' : shortAddress(data.winner)} />
            <Metric label="Time left" value={`${mins}m ${secs}s`} />
          </div>
          <div className="flex min-w-[240px] flex-col gap-2 rounded-xl border border-white/10 bg-white/[0.03] p-3">
            <label className="label">Bid (ETH)</label>
            <input value={bid} onChange={(e) => setBid(e.target.value)} className="input" />
            <div className="buttons">
              <button disabled={actions.pending || currentPhase !== 'Commit'} onClick={() => actions.commitBid(poolKey, bid, salt)} className="action primary">Commit</button>
              <button disabled={actions.pending || currentPhase !== 'Reveal'} onClick={() => actions.revealBid(poolKey, bid, salt)} className="action secondary">Reveal</button>
            </div>
            <button onClick={() => setSalt(`0x${crypto.getRandomValues(new Uint8Array(32)).reduce((s, b) => s + b.toString(16).padStart(2, '0'), '')}` as Hex)} className="salt">Generate new salt</button>
          </div>
        </div>
      )}
    </GlassCard>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return <div className="metric"><p className="label">{label}</p><p className="value">{value}</p></div>;
}
