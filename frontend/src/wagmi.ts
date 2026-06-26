import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { baseSepolia } from 'wagmi/chains';

export const walletConnectProjectId =
  import.meta.env.VITE_RAINBOW_PROJECT_ID ??
  import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ??
  'BERYL_BITS_WALLETCONNECT_PROJECT_ID';

export const wagmiConfig = getDefaultConfig({
  appName: 'Beryl Bits',
  projectId: walletConnectProjectId,
  chains: [baseSepolia],
  transports: {
    [baseSepolia.id]: http('https://sepolia.base.org'),
  },
});
