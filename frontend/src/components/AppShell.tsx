"use client";

import { ConnectWallet } from "@/components/ConnectWallet";
import { TokenBankApp } from "@/components/TokenBankApp";
import { WalletProvider } from "@/lib/wallet";

export function AppShell() {
  return (
    <WalletProvider>
      <div className="min-h-screen bg-zinc-100">
        <header className="border-b border-zinc-200 bg-white">
          <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-4">
            <div>
              <p className="text-sm font-medium text-indigo-600">Foundry Demo</p>
              <h1 className="text-xl font-semibold text-zinc-900">TokenBank</h1>
            </div>
            <ConnectWallet />
          </div>
        </header>

        <main className="mx-auto max-w-4xl px-6 py-8">
          <TokenBankApp />
        </main>
      </div>
    </WalletProvider>
  );
}
