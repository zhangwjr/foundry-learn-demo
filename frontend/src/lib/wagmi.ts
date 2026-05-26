import { createConfig, http, injected } from "wagmi";
import { chain } from "@/lib/config";

export const wagmiConfig = createConfig({
  chains: [chain],
  connectors: [injected()],
  transports: {
    [chain.id]: http(chain.rpcUrls.default.http[0]),
  },
  ssr: true,
});

export async function addAnvilChainToWallet() {
  if (typeof window === "undefined" || !window.ethereum) {
    return;
  }

  await window.ethereum.request({
    method: "wallet_addEthereumChain",
    params: [
      {
        chainId: "0x7a69",
        chainName: "Anvil Local",
        nativeCurrency: {
          name: "Ether",
          symbol: "ETH",
          decimals: 18,
        },
        rpcUrls: [chain.rpcUrls.default.http[0]],
      },
    ],
  });
}
