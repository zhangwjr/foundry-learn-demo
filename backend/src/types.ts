export type TransferRecord = {
  txHash: string;
  logIndex: number;
  blockNumber: number;
  from: string;
  to: string;
  value: string;
};

export type TransferQueryRow = TransferRecord & {
  direction: "in" | "out";
};

export type TransferQueryResult = {
  address: string;
  total: number;
  limit: number;
  offset: number;
  transfers: TransferQueryRow[];
};
