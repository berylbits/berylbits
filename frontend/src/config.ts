import type { Address } from 'viem';

export const contracts = {
  chainId: Number(import.meta.env.VITE_CHAIN_ID ?? 84532),
  b20: (import.meta.env.VITE_B20_TOKEN_ADDRESS ?? '0xB20000000000000000000069d62bC417C3c5ca7E') as Address,
  curve: (import.meta.env.VITE_CURVE_ADDRESS ?? '0x5A0Ee112843DdA023b778c77cffb9904407188E0') as Address,
  forge: (import.meta.env.VITE_FORGE_ADDRESS ?? '0x272d1CBdf4f8D7091A958Af28746990a921BBd68') as Address,
  nft: (import.meta.env.VITE_NFT_ADDRESS ?? '0x3848C9d288bef5083Ea6ca6C5262C7763559d427') as Address,
  teamAllocation: Number(import.meta.env.VITE_TEAM_ALLOCATION ?? 25),
  projectUri: import.meta.env.VITE_PROJECT_URI ?? 'https://berylbits.xyz',
  nftStartBlock: BigInt(import.meta.env.VITE_NFT_START_BLOCK ?? 43360310),
};

export const baseSepoliaExplorer = 'https://sepolia.basescan.org';
