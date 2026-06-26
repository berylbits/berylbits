export const erc20Abi = [
  { type: 'function', name: 'balanceOf', stateMutability: 'view', inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'allowance', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'approve', stateMutability: 'nonpayable', inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'totalSupply', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
] as const;

export const curveAbi = [
  { type: 'function', name: 'quoteBuy', stateMutability: 'view', inputs: [{ name: 'unitCount', type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'quoteSell', stateMutability: 'view', inputs: [{ name: 'unitCount', type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'buy', stateMutability: 'payable', inputs: [{ name: 'unitCount', type: 'uint256' }, { name: 'maxCost', type: 'uint256' }], outputs: [] },
  { type: 'function', name: 'sell', stateMutability: 'nonpayable', inputs: [{ name: 'unitCount', type: 'uint256' }, { name: 'minPayout', type: 'uint256' }], outputs: [] },
  { type: 'function', name: 'marketOutstandingUnits', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'PUBLIC_UNITS', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'BUY_FEE_BPS', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'SELL_PAYOUT_BPS', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'teamWallet', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'teamSellUnlockUnits', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'maxBuyUnitsPerWallet', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'curveBoughtUnits', stateMutability: 'view', inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'uint256' }] },
] as const;

export const forgeAbi = [
  { type: 'function', name: 'forge', stateMutability: 'nonpayable', inputs: [{ name: 'quantity', type: 'uint256' }], outputs: [] },
  { type: 'function', name: 'redeem', stateMutability: 'nonpayable', inputs: [{ name: 'tokenIds', type: 'uint256[]' }], outputs: [] },
  { type: 'function', name: 'redeemAndSell', stateMutability: 'nonpayable', inputs: [{ name: 'tokenIds', type: 'uint256[]' }, { name: 'minPayout', type: 'uint256' }], outputs: [] },
] as const;

export const nftAbi = [
  { type: 'function', name: 'balanceOf', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'ownerOf', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'tokenURI', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'imageSVG', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ type: 'string' }] },
  { type: 'function', name: 'liveSupply', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'totalMinted', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
] as const;
