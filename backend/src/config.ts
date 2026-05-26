import "dotenv/config";
import { defineChain, type Address } from "viem";

const chainId = Number(process.env.CHAIN_ID ?? "31337");
const rpcUrl = process.env.RPC_URL ?? "http://127.0.0.1:8545";

export const chain = defineChain({
  id: chainId,
  name: chainId === 31337 ? "Anvil Local" : `Chain ${chainId}`,
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [rpcUrl] },
  },
});

export const config = {
  rpcUrl,
  chainId,
  tokenAddress: process.env.TOKEN_ADDRESS as Address | undefined,
  startBlock: BigInt(process.env.START_BLOCK ?? "0"),
  port: Number(process.env.PORT ?? "3001"),
  databasePath: process.env.DATABASE_PATH ?? "./data/transfers.db",
  indexBatchSize: BigInt(process.env.INDEX_BATCH_SIZE ?? "2000"),
} as const;

export function assertConfig() {
  if (!config.tokenAddress) {
    throw new Error("请在 .env 中设置 TOKEN_ADDRESS（MyToken 合约地址）");
  }
}
