"use client";

import { shortenAddress, useWallet } from "@/lib/wallet";

export function ConnectWallet() {
  const { address, isConnected, isConnecting, error, connect, disconnect } =
    useWallet();

  return (
    <div className="flex flex-col items-end gap-2">
      {error ? (
        <p className="max-w-xs text-right text-sm text-red-500">{error}</p>
      ) : null}
      {isConnected && address ? (
        <div className="flex items-center gap-3">
          <span className="rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700 ring-1 ring-emerald-200">
            {shortenAddress(address)}
          </span>
          <button
            type="button"
            onClick={disconnect}
            className="rounded-lg border border-zinc-200 px-4 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-50"
          >
            断开
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => void connect()}
          disabled={isConnecting}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isConnecting ? "连接中..." : "连接钱包"}
        </button>
      )}
    </div>
  );
}
