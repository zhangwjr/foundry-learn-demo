"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  type Address,
  type PublicClient,
  type WalletClient,
} from "viem";
import { chain } from "@/lib/config";

type WalletContextValue = {
  address: Address | undefined;
  publicClient: PublicClient;
  walletClient: WalletClient | undefined;
  isConnecting: boolean;
  isConnected: boolean;
  error: string | undefined;
  connect: () => Promise<void>;
  disconnect: () => void;
  refreshClients: () => Promise<void>;
};

const WalletContext = createContext<WalletContextValue | undefined>(undefined);

function createReadClient() {
  return createPublicClient({
    chain,
    transport: http(chain.rpcUrls.default.http[0]),
  });
}

function shortenAddress(address: Address) {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function WalletProvider({ children }: { children: ReactNode }) {
  const [address, setAddress] = useState<Address | undefined>();
  const [walletClient, setWalletClient] = useState<WalletClient | undefined>();
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState<string | undefined>();

  const publicClient = useMemo(() => createReadClient(), []);

  const refreshClients = useCallback(async () => {
    if (typeof window === "undefined" || !window.ethereum) {
      return;
    }

    const client = createWalletClient({
      chain,
      transport: custom(window.ethereum),
    });

    const [accounts, currentChainId] = await Promise.all([
      client.getAddresses(),
      client.getChainId(),
    ]);

    if (accounts.length === 0) {
      setAddress(undefined);
      setWalletClient(undefined);
      return;
    }

    if (currentChainId !== chain.id) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${chain.id.toString(16)}` }],
        });
      } catch (switchError) {
        if (chain.id === 31337) {
          try {
            await window.ethereum.request({
              method: "wallet_addEthereumChain",
              params: [
                {
                  chainId: "0x7a69",
                  chainName: "Anvil Local",
                  nativeCurrency: {
                    name: "Ether",
                    symbol: "ETH",
                    decimals: 18,
                  },
                  rpcUrls: [chain.rpcUrls.default.http[0]],
                },
              ],
            });
          } catch {
            setError("请切换到本地链 (chain id 31337)");
            return;
          }
        } else {
          setError(`请切换到 ${chain.name} (chain id ${chain.id})`);
          return;
        }
      }
    }

    setAddress(accounts[0]);
    setWalletClient(client);
    setError(undefined);
  }, []);

  const connect = useCallback(async () => {
    if (typeof window === "undefined" || !window.ethereum) {
      setError("未检测到 MetaMask 或其他 Web3 钱包");
      return;
    }

    setIsConnecting(true);
    setError(undefined);

    try {
      await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      await refreshClients();
    } catch (connectError) {
      setError(
        connectError instanceof Error ? connectError.message : "连接钱包失败",
      );
    } finally {
      setIsConnecting(false);
    }
  }, [refreshClients]);

  const disconnect = useCallback(() => {
    setAddress(undefined);
    setWalletClient(undefined);
    setError(undefined);
  }, []);

  useEffect(() => {
    if (typeof window === "undefined" || !window.ethereum) {
      return;
    }

    const handleAccountsChanged = (...args: unknown[]) => {
      const accounts = args[0] as string[];
      if (accounts.length === 0) {
        disconnect();
        return;
      }
      void refreshClients();
    };

    const handleChainChanged = () => {
      void refreshClients();
    };

    window.ethereum.on("accountsChanged", handleAccountsChanged);
    window.ethereum.on("chainChanged", handleChainChanged);

    void refreshClients();

    return () => {
      window.ethereum?.removeListener(
        "accountsChanged",
        handleAccountsChanged,
      );
      window.ethereum?.removeListener("chainChanged", handleChainChanged);
    };
  }, [disconnect, refreshClients]);

  const value = useMemo(
    () => ({
      address,
      publicClient,
      walletClient,
      isConnecting,
      isConnected: Boolean(address && walletClient),
      error,
      connect,
      disconnect,
      refreshClients,
    }),
    [
      address,
      publicClient,
      walletClient,
      isConnecting,
      error,
      connect,
      disconnect,
      refreshClients,
    ],
  );

  return (
    <WalletContext.Provider value={value}>{children}</WalletContext.Provider>
  );
}

export function useWallet() {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error("useWallet must be used within WalletProvider");
  }
  return context;
}

export { shortenAddress };
