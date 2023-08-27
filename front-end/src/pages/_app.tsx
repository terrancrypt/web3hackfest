import "@/styles/globals.css";
import type { AppProps } from "next/app";
import Header from "@/components/header/Header";
import { InjectedConnector } from "wagmi/connectors/injected";
import { WalletConnectConnector } from "wagmi/connectors/walletConnect";

// Web#Modal Import
import { EthereumClient, w3mConnectors } from "@web3modal/ethereum";
import { alchemyProvider } from "wagmi/providers/alchemy";
import { Web3Modal } from "@web3modal/react";
import { configureChains, createConfig, sepolia, WagmiConfig } from "wagmi";

export default function App({ Component, pageProps }: AppProps) {
  // Web3Modal Config
  const chains = [sepolia];
  const projectId = "8113267d88fce267d26e0b99c63b53a6";
  const apiKey = "cs5861l2vJk5J5gmRJZgQm9gghoQ82mQ";

  const { publicClient } = configureChains(chains, [
    alchemyProvider({ apiKey }),
  ]);
  const wagmiConfig = createConfig({
    autoConnect: true,
    connectors: w3mConnectors({
      chains,
      projectId,
    }),
    publicClient,
  });
  const ethereumClient = new EthereumClient(wagmiConfig, chains);

  // Start Background
  const randomNumber = (min: number, max: number) => {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  };

  const STAR_COUNT = 1000;
  let result = "";
  for (let i = 0; i < STAR_COUNT; i++) {
    result += `${randomNumber(-50, 50)}vw ${randomNumber(
      -50,
      50
    )}vh ${randomNumber(0, 1)}px ${randomNumber(0, 1)}px #fff,`;
  }

  return (
    <>
      <WagmiConfig config={wagmiConfig}>
        <div className="main"></div>
        <Header />
        <div className="pt-32 container px-20">
          <Component {...pageProps} />
        </div>
      </WagmiConfig>

      <Web3Modal projectId={projectId} ethereumClient={ethereumClient} />
    </>
  );
}
