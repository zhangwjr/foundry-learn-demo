import "dotenv/config";
import {
  createPublicClient,
  defineChain,
  formatUnits,
  http,
  keccak256,
  padHex,
  toHex,
  type Address,
} from "viem";

/** esRNT._locks is the only state variable → storage slot 0. */
const LOCKS_ARRAY_SLOT = 0n;

const DEFAULT_ES_RNT_ADDRESS =
  "0x0E801D84Fa97b50751Dbf25036d067dCf18858bF" as Address;

type LockInfo = {
  user: Address;
  startTime: bigint;
  amount: bigint;
};

function getArrayDataBaseSlot(arraySlot: bigint): bigint {
  return BigInt(keccak256(padHex(toHex(arraySlot), { size: 32 })));
}

/** LockInfo packs `user` (20) + `startTime` (8) in one slot; `amount` in the next. */
function decodePackedLockSlot(slotValue: bigint): Pick<LockInfo, "user" | "startTime"> {
  const userMask = (1n << 160n) - 1n;
  const startTimeMask = (1n << 64n) - 1n;
  const user = `0x${(slotValue & userMask).toString(16).padStart(40, "0")}` as Address;
  const startTime = (slotValue >> 160n) & startTimeMask;
  return { user, startTime };
}

async function readLocksLength(
  client: ReturnType<typeof createPublicClient>,
  contract: Address,
): Promise<number> {
  const lengthSlot = await client.getStorageAt({
    address: contract,
    slot: toHex(LOCKS_ARRAY_SLOT),
  });
  if (!lengthSlot) {
    return 0;
  }
  return Number(BigInt(lengthSlot));
}

async function readLockAt(
  client: ReturnType<typeof createPublicClient>,
  contract: Address,
  index: number,
): Promise<LockInfo> {
  const base = getArrayDataBaseSlot(LOCKS_ARRAY_SLOT);
  const packedSlot = base + BigInt(index * 2);
  const amountSlot = packedSlot + 1n;

  const [packedHex, amountHex] = await Promise.all([
    client.getStorageAt({ address: contract, slot: toHex(packedSlot) }),
    client.getStorageAt({ address: contract, slot: toHex(amountSlot) }),
  ]);

  const { user, startTime } = decodePackedLockSlot(BigInt(packedHex ?? "0x0"));
  const amount = BigInt(amountHex ?? "0x0");

  return { user, startTime, amount };
}

async function main() {
  const rpcUrl = process.env.ANVIL_RPC_URL ?? process.env.RPC_URL;
  if (!rpcUrl) {
    throw new Error("请在 .env 中设置 ANVIL_RPC_URL 或 RPC_URL");
  }

  const contract =
    (process.env.ES_RNT_ADDRESS as Address | undefined) ?? DEFAULT_ES_RNT_ADDRESS;

  const chainId = Number(process.env.CHAIN_ID ?? "31337");
  const chain = defineChain({
    id: chainId,
    name: chainId === 31337 ? "Anvil Local" : `Chain ${chainId}`,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });

  const client = createPublicClient({ chain, transport: http(rpcUrl) });

  const code = await client.getBytecode({ address: contract });
  if (!code || code === "0x") {
    throw new Error(`合约 ${contract} 在当前 RPC 上无代码，请确认 Anvil 已启动且地址正确`);
  }

  const length = await readLocksLength(client, contract);
  console.log(`esRNT: ${contract}`);
  console.log(`_locks.length: ${length}\n`);

  for (let i = 0; i < length; i++) {
    const lock = await readLockAt(client, contract, i);
    console.log(
      `locks[${i}]: user:${lock.user}, startTime:${lock.startTime}, amount:${formatUnits(lock.amount, 18)}`,
    );
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
