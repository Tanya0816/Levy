export const levyHookAbi = [
  { type: 'function', name: 'currentEpoch', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'poolParams', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }], outputs: [
    { name: 'reservePrice', type: 'uint256' }, { name: 'epochLength', type: 'uint256' },
    { name: 'commitWindow', type: 'uint256' }, { name: 'revealWindow', type: 'uint256' },
    { name: 'claimWindow', type: 'uint256' }, { name: 'lpDistribution', type: 'uint32' },
    { name: 'noShowRefund', type: 'uint32' }, { name: 'settlementAsset', type: 'address' }, { name: 'configured', type: 'bool' }
  ] },
  { type: 'function', name: 'auctions', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }, { name: '', type: 'uint256' }], outputs: [
    { name: 'epochStart', type: 'uint256' }, { name: 'commitDeadline', type: 'uint256' },
    { name: 'revealDeadline', type: 'uint256' }, { name: 'claimDeadline', type: 'uint256' },
    { name: 'winner', type: 'address' }, { name: 'winningBid', type: 'uint256' },
    { name: 'revealed', type: 'bool' }, { name: 'resolved', type: 'bool' }
  ] },
  { type: 'function', name: 'lpPool', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }, { name: '', type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'lastDepositBlock', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }, { name: '', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'claimableAmount', stateMutability: 'view', inputs: [{ name: '', type: 'bytes32' }, { name: '', type: 'uint256' }, { name: '', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'startEpoch', stateMutability: 'nonpayable', inputs: [{ name: 'key', type: 'tuple', components: [
    { name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }
  ] }], outputs: [] },
  { type: 'function', name: 'commitBid', stateMutability: 'nonpayable', inputs: [{ name: 'key', type: 'tuple', components: [
    { name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }
  ] }, { name: 'commitHash', type: 'bytes32' }], outputs: [] },
  { type: 'function', name: 'revealBid', stateMutability: 'payable', inputs: [
    { name: 'key', type: 'tuple', components: [
      { name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }
    ] }, { name: 'bidAmount', type: 'uint256' }, { name: 'salt', type: 'bytes32' }
  ], outputs: [] },
  { type: 'function', name: 'settleForfeiture', stateMutability: 'nonpayable', inputs: [{ name: 'key', type: 'tuple', components: [
    { name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }
  ] }], outputs: [] },
  { type: 'function', name: 'claimPayout', stateMutability: 'nonpayable', inputs: [
    { name: 'key', type: 'tuple', components: [
      { name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }
    ] }, { name: 'epoch', type: 'uint256' }
  ], outputs: [] },
  { type: 'event', name: 'EpochStarted', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: false, name: 'epochStarted', type: 'uint256' }] },
  { type: 'event', name: 'BidCommitted', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: true, name: 'bidder', type: 'address' }] },
  { type: 'event', name: 'BidRevealed', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: true, name: 'bidder', type: 'address' }, { indexed: false, name: 'bidAmount', type: 'uint256' }] },
  { type: 'event', name: 'WinnerClaimed', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: true, name: 'winner', type: 'address' }] },
  { type: 'event', name: 'WinnerForfeited', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: true, name: 'winner', type: 'address' }, { indexed: false, name: 'refund', type: 'uint256' }, { indexed: false, name: 'toLPs', type: 'uint256' }] },
  { type: 'event', name: 'LPDistributed', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: false, name: 'toLPs', type: 'uint256' }] },
  { type: 'event', name: 'LPClaimed', inputs: [{ indexed: true, name: 'poolId', type: 'bytes32' }, { indexed: true, name: 'epoch', type: 'uint256' }, { indexed: true, name: 'claimer', type: 'address' }, { indexed: false, name: 'amount', type: 'uint256' }] },
] as const;
