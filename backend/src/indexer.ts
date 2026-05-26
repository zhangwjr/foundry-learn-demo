import {
  createPublicClient,
  http,
  type Address,
} from "viem";
import { myTokenAbi } from "./abi.js";
import { chain, config } from "./config.js";
import type { TransferStore } from "./db.js";
import type { TransferRecord } from "./types.js";

type TransferEventLog = {
  args: {
    from?: Address;
    to?: Address;
    value?: bigint;
  };
  transactionHash: `0x${string}`;
  logIndex: number | null;
  blockNumber: bigint;
};

function toTransferRecord(log: TransferEventLog): TransferRecord | null {
  const { from, to, value } = log.args;

  if (!from || !to || value === undefined || log.logIndex === null) {
    return null;
  }

  return {
    txHash: log.transactionHash,
    logIndex: log.logIndex,
    blockNumber: Number(log.blockNumber),
    from,
    to,
    value: value.toString(),
  };
}

export class TransferIndexer {
  private client = createPublicClient({
    chain,
    transport: http(config.rpcUrl),
  });

  private unwatch: (() => void) | undefined;

  constructor(
    private tokenAddress: Address,
    private store: TransferStore,
  ) {}

  async syncHistorical() {
    const latestBlock = await this.client.getBlockNumber();
    const savedBlock = this.store.getLastIndexedBlock();
    const fromBlock = savedBlock !== null ? savedBlock + 1n : config.startBlock;

    if (fromBlock > latestBlock) {
      console.log(`历史索引已是最新，当前区块 ${latestBlock.toString()}`);
      return;
    }

    console.log(
      `开始历史索引：区块 ${fromBlock.toString()} -> ${latestBlock.toString()}`,
    );

    let cursor = fromBlock;

    while (cursor <= latestBlock) {
      const toBlock =
        cursor + config.indexBatchSize - 1n > latestBlock
          ? latestBlock
          : cursor + config.indexBatchSize - 1n;

      const logs = await this.client.getContractEvents({
        address: this.tokenAddress,
        abi: myTokenAbi,
        eventName: "Transfer",
        fromBlock: cursor,
        toBlock,
      });

      const records = logs
        .map((log) => toTransferRecord(log))
        .filter((record): record is TransferRecord => record !== null);

      const inserted = this.store.insertTransfers(records);
      this.store.setLastIndexedBlock(toBlock);

      console.log(
        `已索引区块 ${cursor.toString()}-${toBlock.toString()}，事件 ${records.length} 条，新增 ${inserted} 条`,
      );

      cursor = toBlock + 1n;
    }
  }

  startLiveWatch() {
    this.unwatch = this.client.watchContractEvent({
      address: this.tokenAddress,
      abi: myTokenAbi,
      eventName: "Transfer",
      onLogs: (logs) => {
        const records = logs
          .map((log) => toTransferRecord(log))
          .filter((record): record is TransferRecord => record !== null);

        if (records.length === 0) {
          return;
        }

        const inserted = this.store.insertTransfers(records);
        const maxBlock = records.reduce(
          (max, record) => (record.blockNumber > max ? record.blockNumber : max),
          0,
        );

        if (maxBlock > 0) {
          this.store.setLastIndexedBlock(BigInt(maxBlock));
        }

        for (const record of records) {
          console.log(
            `[Transfer] block=${record.blockNumber} tx=${record.txHash} from=${record.from} to=${record.to} value=${record.value}`,
          );
        }

        if (inserted > 0) {
          console.log(`实时索引新增 ${inserted} 条 Transfer 记录`);
        }
      },
      onError: (error) => {
        console.error("[Transfer listener error]", error);
      },
    });

    console.log("MyToken Transfer 实时监听已启动");
  }

  stop() {
    this.unwatch?.();
    this.unwatch = undefined;
  }
}
