"use client";

import { useCallback, useEffect } from "react";
import {
  useConnect,
  useConnection,
  useConnectors,
  useDisconnect,
  useSwitchChain,
} from "wagmi";
import { chain } from "@/lib/config";
import { shortenAddress } from "@/lib/format";
import { addAnvilChainToWallet } from "@/lib/wagmi";

export function ConnectWallet() {
  const { address, isConnected, chainId, isConnecting } = useConnection();
  const connectors = useConnectors();
  const { mutate: connect, isPending: isConnectPending, error: connectError } =
    useConnect();
  const { mutate: disconnect } = useDisconnect();
  const { mutate: switchChain, error: switchError } = useSwitchChain();

  const connector = connectors[0];

  const ensureTargetChain = useCallback(() => {
    if (!isConnected || chainId === chain.id) {
      return;
    }

    switchChain(
      { chainId: chain.id },
      {
        onError: async () => {
          if (chain.id !== 31337) {
            return;
          }

          try {
            await addAnvilChainToWallet();
            switchChain({ chainId: chain.id });
          } catch {
            // switchError surfaces the failure in the UI
          }
        },
      },
    );
  }, [chainId, isConnected, switchChain]);

  useEffect(() => {
    ensureTargetChain();
  }, [ensureTargetChain]);

  const handleConnect = () => {
    if (!connector) {
      return;
    }

    connect({ connector, chainId: chain.id });
  };

  const errorMessage = (() => {
    if (!connector) {
      return "未检测到 MetaMask 或其他 Web3 钱包";
    }

    if (connectError) {
      return connectError.message;
    }

    if (switchError) {
      if (chain.id === 31337) {
        return "请切换到本地链 (chain id 31337)";
      }
      return `请切换到 ${chain.name} (chain id ${chain.id})`;
    }

    return undefined;
  })();

  const isBusy = isConnecting || isConnectPending;

  return (
    <div className="flex flex-col items-end gap-2">
      {errorMessage ? (
        <p className="max-w-xs text-right text-sm text-red-500">{errorMessage}</p>
      ) : null}
      {isConnected && address ? (
        <div className="flex items-center gap-3">
          <span className="rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700 ring-1 ring-emerald-200">
            {shortenAddress(address)}
          </span>
          <button
            type="button"
            onClick={() => disconnect()}
            className="rounded-lg border border-zinc-200 px-4 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-50"
          >
            断开
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={handleConnect}
          disabled={isBusy || !connector}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isBusy ? "连接中..." : "连接钱包"}
        </button>
      )}
    </div>
  );
}
