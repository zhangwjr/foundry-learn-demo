import "dotenv/config";
import {
  createPublicClient,
  defineChain,
  formatEther,
  http,
  type Address,
} from "viem";
import { nftMarketAbi } from "./abi.js";

const chainId = Number(process.env.CHAIN_ID ?? "31337");
const rpcUrl = process.env.RPC_URL ?? "http://127.0.0.1:8545";
const nftMarketAddress = process.env.NFT_MARKET_ADDRESS as Address | undefined;

const chain = defineChain({
  id: chainId,
  name: chainId === 31337 ? "Anvil Local" : `Chain ${chainId}`,
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: [rpcUrl] },
  },
});

function formatTimestamp(date = new Date()) {
  return date.toISOString();
}

async function main() {
  if (!nftMarketAddress) {
    console.error("请在 .env 中设置 NFT_MARKET_ADDRESS");
    process.exit(1);
  }

  const client = createPublicClient({
    chain,
    transport: http(rpcUrl),
  });

  console.log("NFTMarket 事件监听已启动");
  console.log(`RPC: ${rpcUrl}`);
  console.log(`Chain ID: ${chainId}`);
  console.log(`NFTMarket: ${nftMarketAddress}`);
  console.log("监听事件: Listed, Sold");
  console.log("等待链上交易...\n");

  const unwatchListed = client.watchContractEvent({
    address: nftMarketAddress,
    abi: nftMarketAbi,
    eventName: "Listed",
    onLogs: (logs) => {
      for (const log of logs) {
        const { seller, tokenId, price } = log.args;

        console.log(
          [
            `[${formatTimestamp()}] NFT 上架`,
            `tx=${log.transactionHash}`,
            `block=${log.blockNumber}`,
            `seller=${seller}`,
            `tokenId=${tokenId?.toString()}`,
            `price=${formatEther(price ?? 0n)} MTK`,
          ].join(" | "),
        );
      }
    },
    onError: (error) => {
      console.error("[Listed listener error]", error);
    },
  });

  const unwatchSold = client.watchContractEvent({
    address: nftMarketAddress,
    abi: nftMarketAbi,
    eventName: "Sold",
    onLogs: (logs) => {
      for (const log of logs) {
        const { seller, buyer, tokenId, price } = log.args;

        console.log(
          [
            `[${formatTimestamp()}] NFT 成交`,
            `tx=${log.transactionHash}`,
            `block=${log.blockNumber}`,
            `seller=${seller}`,
            `buyer=${buyer}`,
            `tokenId=${tokenId?.toString()}`,
            `price=${formatEther(price ?? 0n)} MTK`,
          ].join(" | "),
        );
      }
    },
    onError: (error) => {
      console.error("[Sold listener error]", error);
    },
  });

  const shutdown = () => {
    console.log("\n停止监听...");
    unwatchListed();
    unwatchSold();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

void main();
