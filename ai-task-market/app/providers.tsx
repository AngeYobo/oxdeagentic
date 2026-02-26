'use client';

import { WagmiProvider, createConfig, http } from 'wagmi';
import { base, baseSepolia } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import '@rainbow-me/rainbowkit/styles.css';

declare global {
  var __wagmiConfig: ReturnType<typeof createConfig> | undefined;
  var __queryClient: QueryClient | undefined;
}

const config =
  globalThis.__wagmiConfig ??
  createConfig({
    ssr: true,
    connectors: [injected({ shimDisconnect: true })],
    chains: [base, baseSepolia],
    transports: {
      [base.id]: http(),
      [baseSepolia.id]: http(),
    },
  });

globalThis.__wagmiConfig = config;

const queryClient = globalThis.__queryClient ?? new QueryClient();
globalThis.__queryClient = queryClient;

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
