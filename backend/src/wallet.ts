import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  defineChain,
  formatUnits,
  http,
  parseUnits,
  type Address,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const erc20Abi = [
  {
    type: "function",
    name: "transfer",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
  },
] as const;

function parseArgs(args: string[]) {
  let to: Address | undefined;
  let amount: string | undefined;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--to" && args[i + 1]) {
      to = args[i + 1] as Address;
      i++;
    } else if (args[i] === "--amount" && args[i + 1]) {
      amount = args[i + 1];
      i++;
    }
  }

  return { to, amount };
}

function loadPrivateKey(): Hex {
  const raw = process.env.PRIVATE_KEY;
  if (!raw) {
    throw new Error("请在 .env 中设置 PRIVATE_KEY");
  }
  return (raw.startsWith("0x") ? raw : `0x${raw}`) as Hex;
}

async function main() {
  const tokenAddress = process.env.TOKEN_ADDRESS as Address | undefined;
  const rpcUrl = process.env.ANVIL_RPC_URL;

  if (!tokenAddress) {
    throw new Error("请在 .env 中设置 TOKEN_ADDRESS");
  }
  if (!rpcUrl) {
    throw new Error("请在 .env 中设置 ANVIL_RPC_URL");
  }

  const { to, amount } = parseArgs(process.argv.slice(2));
  if (!to) {
    throw new Error("请提供 --to 收款地址，例如: --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
  }
  if (!amount) {
    throw new Error("请提供 --amount 转账数量，例如: --amount 100");
  }

  const chainId = Number(process.env.CHAIN_ID ?? "31337");
  const chain = defineChain({
    id: chainId,
    name: chainId === 31337 ? "Anvil Local" : `Chain ${chainId}`,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: {
      default: { http: [rpcUrl] },
    },
  });

  const account = privateKeyToAccount(loadPrivateKey());
  const publicClient = createPublicClient({ chain, transport: http(rpcUrl) });
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  });

  const [decimals, symbol, balanceBefore] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "decimals",
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "symbol",
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    }),
  ]);

  const amountRaw = parseUnits(amount, decimals);
  if (balanceBefore < amountRaw) {
    throw new Error(
      `余额不足：当前 ${formatUnits(balanceBefore, decimals)} ${symbol}，需要 ${amount} ${symbol}`,
    );
  }

  console.log(`发送方: ${account.address}`);
  console.log(`收款方: ${to}`);
  console.log(`数量: ${amount} ${symbol} (${amountRaw.toString()} 最小单位)`);

  const hash = await walletClient.writeContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "transfer",
    args: [to, amountRaw],
  });

  console.log(`交易已发送: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") {
    throw new Error(`交易失败: ${hash}`);
  }

  const balanceAfter = await publicClient.readContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [account.address],
  });

  console.log(`交易已确认，区块: ${receipt.blockNumber}`);
  console.log(`剩余余额: ${formatUnits(balanceAfter, decimals)} ${symbol}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
