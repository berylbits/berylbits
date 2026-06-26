import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { activeChain, rpcUrl } from './config';

export const walletConnectProjectId =
  import.meta.env.VITE_RAINBOW_PROJECT_ID ??
  import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ??
  'BERYL_BITS_WALLETCONNECT_PROJECT_ID';

export const wagmiConfig = getDefaultConfig({
  appName: 'Beryl Bits',
  projectId: walletConnectProjectId,
  chains: [activeChain],
  transports: {
    [activeChain.id]: http(rpcUrl),
  },
});
