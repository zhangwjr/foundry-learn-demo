import express from "express";
import { getAddress, isAddress } from "viem";
import type { TransferStore } from "./db.js";

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

function parsePositiveInt(value: unknown, fallback: number) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    return fallback;
  }
  return parsed;
}

function parseDirection(value: unknown): "in" | "out" | "all" {
  if (value === "in" || value === "out" || value === "all") {
    return value;
  }
  return "all";
}

export function createServer(store: TransferStore) {
  const app = express();

  app.get("/health", (_req, res) => {
    res.json({ status: "ok" });
  });

  app.get("/api/transfers/:address", (req, res) => {
    const rawAddress = req.params.address;

    if (!isAddress(rawAddress)) {
      res.status(400).json({ error: "无效的钱包地址" });
      return;
    }

    const limit = Math.min(
      parsePositiveInt(req.query.limit, DEFAULT_LIMIT) || DEFAULT_LIMIT,
      MAX_LIMIT,
    );
    const offset = parsePositiveInt(req.query.offset, 0);
    const direction = parseDirection(req.query.direction);

    const result = store.getTransfersByAddress(getAddress(rawAddress), {
      limit,
      offset,
      direction,
    });

    res.json(result);
  });

  return app;
}
