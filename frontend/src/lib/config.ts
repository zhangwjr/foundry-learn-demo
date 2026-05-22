import { defineChain, type Chain } from "viem";
import { localhost, mainnet, sepolia } from "viem/chains";

const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "31337");

const customLocalhost = defineChain({
  ...localhost,
  id: 31337,
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_RPC_URL ?? "http://127.0.0.1:8545"],
    },
  },
});

const chainsById: Record<number, Chain> = {
  31337: customLocalhost,
  1: mainnet,
  11155111: sepolia,
};

export const chain = chainsById[chainId] ?? customLocalhost;

export const tokenAddress = process.env
  .NEXT_PUBLIC_TOKEN_ADDRESS as `0x${string}` | undefined;

export const tokenBankAddress = process.env
  .NEXT_PUBLIC_TOKEN_BANK_ADDRESS as `0x${string}` | undefined;

export function isConfigured() {
  return Boolean(tokenAddress && tokenBankAddress);
}
