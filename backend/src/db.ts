import Database from "better-sqlite3";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type { TransferQueryResult, TransferRecord } from "./types.js";

const LAST_INDEXED_BLOCK_KEY = "last_indexed_block";

export class TransferStore {
  private db: Database.Database;

  constructor(databasePath: string) {
    mkdirSync(dirname(databasePath), { recursive: true });
    this.db = new Database(databasePath);
    this.db.pragma("journal_mode = WAL");
    this.initSchema();
  }

  private initSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tx_hash TEXT NOT NULL,
        log_index INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        from_address TEXT NOT NULL,
        to_address TEXT NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(tx_hash, log_index)
      );

      CREATE INDEX IF NOT EXISTS idx_transfers_from
        ON transfers(from_address);
      CREATE INDEX IF NOT EXISTS idx_transfers_to
        ON transfers(to_address);
      CREATE INDEX IF NOT EXISTS idx_transfers_block
        ON transfers(block_number DESC, log_index DESC);

      CREATE TABLE IF NOT EXISTS indexer_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    `);
  }

  getLastIndexedBlock(): bigint | null {
    const row = this.db
      .prepare("SELECT value FROM indexer_state WHERE key = ?")
      .get(LAST_INDEXED_BLOCK_KEY) as { value: string } | undefined;

    return row ? BigInt(row.value) : null;
  }

  setLastIndexedBlock(blockNumber: bigint) {
    this.db
      .prepare(
        `
        INSERT INTO indexer_state (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      `,
      )
      .run(LAST_INDEXED_BLOCK_KEY, blockNumber.toString());
  }

  insertTransfers(records: TransferRecord[]) {
    if (records.length === 0) {
      return 0;
    }

    const insert = this.db.prepare(`
      INSERT OR IGNORE INTO transfers (
        tx_hash,
        log_index,
        block_number,
        from_address,
        to_address,
        value
      ) VALUES (?, ?, ?, ?, ?, ?)
    `);

    const insertMany = this.db.transaction((rows: TransferRecord[]) => {
      let inserted = 0;

      for (const row of rows) {
        const result = insert.run(
          row.txHash.toLowerCase(),
          row.logIndex,
          row.blockNumber,
          row.from.toLowerCase(),
          row.to.toLowerCase(),
          row.value,
        );

        inserted += result.changes;
      }

      return inserted;
    });

    return insertMany(records);
  }

  getTransfersByAddress(
    address: string,
    options: {
      limit: number;
      offset: number;
      direction?: "in" | "out" | "all";
    },
  ): TransferQueryResult {
    const normalizedAddress = address.toLowerCase();
    const { limit, offset, direction = "all" } = options;

    const whereClause =
      direction === "in"
        ? "to_address = @address"
        : direction === "out"
          ? "from_address = @address"
          : "(from_address = @address OR to_address = @address)";

    const totalRow = this.db
      .prepare(`SELECT COUNT(*) AS total FROM transfers WHERE ${whereClause}`)
      .get({ address: normalizedAddress }) as { total: number };

    const rows = this.db
      .prepare(
        `
        SELECT
          tx_hash AS txHash,
          log_index AS logIndex,
          block_number AS blockNumber,
          from_address AS "from",
          to_address AS "to",
          value
        FROM transfers
        WHERE ${whereClause}
        ORDER BY block_number DESC, log_index DESC
        LIMIT @limit OFFSET @offset
      `,
      )
      .all({
        address: normalizedAddress,
        limit,
        offset,
      }) as Array<{
      txHash: string;
      logIndex: number;
      blockNumber: number;
      from: string;
      to: string;
      value: string;
    }>;

    return {
      address: normalizedAddress,
      total: totalRow.total,
      limit,
      offset,
      transfers: rows.map((row) => ({
        ...row,
        direction: row.to === normalizedAddress ? "in" : "out",
      })),
    };
  }

  close() {
    this.db.close();
  }
}
