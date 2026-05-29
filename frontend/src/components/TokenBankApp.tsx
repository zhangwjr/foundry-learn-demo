"use client";

import { useCallback, useEffect, useState } from "react";
import { formatUnits, parseSignature, parseUnits } from "viem";
import { erc20PermitAbi, tokenBankAbi } from "@/lib/abi";
import { isConfigured, tokenAddress, tokenBankAddress, chain } from "@/lib/config";
import {
  useConnection,
  usePublicClient,
  useWalletClient,
} from "wagmi";

type TokenInfo = {
  symbol: string;
  decimals: number;
};

function formatTokenAmount(value: bigint, decimals: number) {
  return formatUnits(value, decimals);
}

export function TokenBankApp() {
  const { address, isConnected } = useConnection();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  const [tokenInfo, setTokenInfo] = useState<TokenInfo | null>(null);
  const [tokenBalance, setTokenBalance] = useState<bigint>(0n);
  const [bankDeposit, setBankDeposit] = useState<bigint>(0n);
  const [depositAmount, setDepositAmount] = useState("");
  const [permitDepositAmount, setPermitDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [supportsPermit, setSupportsPermit] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | undefined>();
  const [isLoading, setIsLoading] = useState(false);

  const configured = isConfigured();

  const refreshBalances = useCallback(async () => {
    if (!configured || !address || !tokenAddress || !tokenBankAddress || !publicClient) {
      return;
    }

    try {
      const [tokenCode, bankCode] = await Promise.all([
        publicClient.getBytecode({ address: tokenAddress }),
        publicClient.getBytecode({ address: tokenBankAddress }),
      ]);

      if (!tokenCode || !bankCode) {
        setTokenInfo(null);
        setTokenBalance(0n);
        setBankDeposit(0n);
        setSupportsPermit(false);
        setWithdrawAmount("");
        setStatusMessage(
          "链上未找到合约，请确认 Anvil 已启动并在 foundry 目录重新部署，然后更新 frontend/.env.local 中的地址。",
        );
        return;
      }

      const [symbol, decimals, balance, deposit, permitSupported] = await Promise.all([
        publicClient.readContract({
          address: tokenAddress,
          abi: erc20PermitAbi,
          functionName: "symbol",
        }),
        publicClient.readContract({
          address: tokenAddress,
          abi: erc20PermitAbi,
          functionName: "decimals",
        }),
        publicClient.readContract({
          address: tokenAddress,
          abi: erc20PermitAbi,
          functionName: "balanceOf",
          args: [address],
        }),
        publicClient.readContract({
          address: tokenBankAddress,
          abi: tokenBankAbi,
          functionName: "deposits",
          args: [address],
        }),
        publicClient
          .readContract({
            address: tokenAddress,
            abi: erc20PermitAbi,
            functionName: "nonces",
            args: [address],
          })
          .then(() => true)
          .catch(() => false),
      ]);

      setTokenInfo({ symbol, decimals: Number(decimals) });
      setTokenBalance(balance);
      setBankDeposit(deposit);
      setSupportsPermit(permitSupported);
      setWithdrawAmount(formatTokenAmount(deposit, Number(decimals)));
      setStatusMessage(undefined);
    } catch (error) {
      setTokenInfo(null);
      setTokenBalance(0n);
      setBankDeposit(0n);
      setSupportsPermit(false);
      setWithdrawAmount("");
      setStatusMessage(
        error instanceof Error
          ? `读取合约失败：${error.message}`
          : "读取合约失败，请检查 RPC 与合约地址配置",
      );
    }
  }, [address, configured, publicClient]);

  useEffect(() => {
    void refreshBalances().catch(() => {
      // refreshBalances handles and surfaces errors via statusMessage
    });
  }, [refreshBalances]);

  const handleDeposit = async () => {
    if (
      !walletClient ||
      !address ||
      !tokenAddress ||
      !tokenBankAddress ||
      !publicClient
    ) {
      setStatusMessage("钱包或合约尚未就绪，请稍后重试");
      return;
    }

    if (!tokenInfo) {
      setStatusMessage("正在加载 Token 信息，请稍后重试");
      return;
    }

    const amount = depositAmount.trim();
    if (!amount || !/^\d+(\.\d+)?$/.test(amount) || Number(amount) <= 0) {
      setStatusMessage("请输入有效的存款金额，例如 100");
      return;
    }

    try {
      const parsedAmount = parseUnits(amount, tokenInfo.decimals);

      if (parsedAmount > tokenBalance) {
        setStatusMessage(
          `余额不足：钱包里有 ${formatTokenAmount(tokenBalance, tokenInfo.decimals)} ${tokenInfo.symbol}，无法存入 ${amount}`,
        );
        return;
      }

      setIsLoading(true);
      setStatusMessage(undefined);

      const approveHash = await walletClient.writeContract({
        account: address,
        chain,
        address: tokenAddress,
        abi: erc20PermitAbi,
        functionName: "approve",
        args: [tokenBankAddress, parsedAmount],
      });

      await publicClient.waitForTransactionReceipt({ hash: approveHash });

      const depositHash = await walletClient.writeContract({
        account: address,
        chain,
        address: tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "deposit",
      });

      await publicClient.waitForTransactionReceipt({ hash: depositHash });

      setDepositAmount("");
      setStatusMessage(`存款成功：${amount} ${tokenInfo.symbol}`);
      await refreshBalances();
    } catch (error) {
      setStatusMessage(
        error instanceof Error ? error.message : "存款失败，请重试",
      );
    } finally {
      setIsLoading(false);
    }
  };

  const handlePermitDeposit = async () => {
    if (
      !walletClient ||
      !address ||
      !tokenAddress ||
      !tokenBankAddress ||
      !publicClient
    ) {
      setStatusMessage("钱包或合约尚未就绪，请稍后重试");
      return;
    }

    if (!tokenInfo) {
      setStatusMessage("正在加载 Token 信息，请稍后重试");
      return;
    }

    if (!supportsPermit) {
      setStatusMessage(
        "当前 Token 不支持 EIP-2612 签名授权，请部署 MyPermitToken 并更新 NEXT_PUBLIC_TOKEN_ADDRESS。",
      );
      return;
    }

    const amount = permitDepositAmount.trim();
    if (!amount || !/^\d+(\.\d+)?$/.test(amount) || Number(amount) <= 0) {
      setStatusMessage("请输入有效的存款金额，例如 100");
      return;
    }

    try {
      const parsedAmount = parseUnits(amount, tokenInfo.decimals);

      if (parsedAmount > tokenBalance) {
        setStatusMessage(
          `余额不足：钱包里有 ${formatTokenAmount(tokenBalance, tokenInfo.decimals)} ${tokenInfo.symbol}，无法存入 ${amount}`,
        );
        return;
      }

      setIsLoading(true);
      setStatusMessage(undefined);

      const [tokenName, nonce] = await Promise.all([
        publicClient.readContract({
          address: tokenAddress,
          abi: erc20PermitAbi,
          functionName: "name",
        }),
        publicClient.readContract({
          address: tokenAddress,
          abi: erc20PermitAbi,
          functionName: "nonces",
          args: [address],
        }),
      ]);

      const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

      const signature = await walletClient.signTypedData({
        account: address,
        domain: {
          name: tokenName,
          version: "1",
          chainId: chain.id,
          verifyingContract: tokenAddress,
        },
        types: {
          Permit: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
            { name: "value", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" },
          ],
        },
        primaryType: "Permit",
        message: {
          owner: address,
          spender: tokenBankAddress,
          value: parsedAmount,
          nonce,
          deadline,
        },
      });

      const { v, r, s } = parseSignature(signature);

      const depositHash = await walletClient.writeContract({
        account: address,
        chain,
        address: tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "permitDeposit",
        args: [address, parsedAmount, deadline, Number(v), r, s],
      });

      await publicClient.waitForTransactionReceipt({ hash: depositHash });

      setPermitDepositAmount("");
      setStatusMessage(`签名存款成功：${amount} ${tokenInfo.symbol}`);
      await refreshBalances();
    } catch (error) {
      setStatusMessage(
        error instanceof Error ? error.message : "签名存款失败，请重试",
      );
    } finally {
      setIsLoading(false);
    }
  };

  const handleWithdraw = async () => {
    if (
      !walletClient ||
      !address ||
      !tokenBankAddress ||
      !tokenInfo ||
      !publicClient
    ) {
      return;
    }

    if (bankDeposit === 0n) {
      setStatusMessage("当前没有可提取的存款");
      return;
    }

    setIsLoading(true);
    setStatusMessage(undefined);

    try {
      const hash = await walletClient.writeContract({
        account: address,
        chain,
        address: tokenBankAddress,
        abi: tokenBankAbi,
        functionName: "withdraw",
      });

      await publicClient.waitForTransactionReceipt({ hash });

      const withdrawn = formatTokenAmount(bankDeposit, tokenInfo.decimals);
      setWithdrawAmount("");
      setStatusMessage(`取款成功：${withdrawn} ${tokenInfo.symbol}`);
      await refreshBalances();
    } catch (error) {
      setStatusMessage(
        error instanceof Error ? error.message : "取款失败，请重试",
      );
    } finally {
      setIsLoading(false);
    }
  };

  if (!configured) {
    return (
      <section className="rounded-2xl border border-amber-200 bg-amber-50 p-6 text-amber-900">
        <h2 className="text-lg font-semibold">请先配置合约地址</h2>
        <p className="mt-2 text-sm leading-6">
          在 <code className="rounded bg-amber-100 px-1">frontend/.env.local</code>{" "}
          中设置 <code className="rounded bg-amber-100 px-1">NEXT_PUBLIC_TOKEN_ADDRESS</code>{" "}
          和{" "}
          <code className="rounded bg-amber-100 px-1">NEXT_PUBLIC_TOKEN_BANK_ADDRESS</code>
          ，然后重启开发服务器。
        </p>
      </section>
    );
  }

  return (
    <div className="space-y-6">
      <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-zinc-900">账户余额</h2>
        {!isConnected ? (
          <p className="mt-3 text-sm text-zinc-500">请先连接钱包查看余额</p>
        ) : (
          <dl className="mt-4 grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl bg-zinc-50 p-4">
              <dt className="text-sm text-zinc-500">钱包 Token 余额</dt>
              <dd className="mt-1 text-2xl font-semibold text-zinc-900">
                {tokenInfo
                  ? `${formatTokenAmount(tokenBalance, tokenInfo.decimals)} ${tokenInfo.symbol}`
                  : "加载中..."}
              </dd>
            </div>
            <div className="rounded-xl bg-indigo-50 p-4">
              <dt className="text-sm text-indigo-600">TokenBank 存款</dt>
              <dd className="mt-1 text-2xl font-semibold text-indigo-900">
                {tokenInfo
                  ? `${formatTokenAmount(bankDeposit, tokenInfo.decimals)} ${tokenInfo.symbol}`
                  : "加载中..."}
              </dd>
            </div>
          </dl>
        )}
      </section>

      <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-zinc-900">存款到 TokenBank</h2>
        <p className="mt-2 text-sm text-zinc-500">
          请输入 Token 数量（不是 wei）。例如存 100 个 MTK，输入{" "}
          <code className="rounded bg-zinc-100 px-1">100</code>，不要输入{" "}
          <code className="rounded bg-zinc-100 px-1">100000000000000000000</code>
          。
        </p>
        <div className="mt-4 flex flex-col gap-3 sm:flex-row">
          <input
            type="text"
            inputMode="decimal"
            placeholder="例如 100"
            value={depositAmount}
            onChange={(event) => setDepositAmount(event.target.value)}
            disabled={!isConnected || isLoading}
            className="w-full rounded-lg border border-zinc-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-2 focus:ring-indigo-100 disabled:bg-zinc-50"
          />
          <button
            type="button"
            onClick={() => void handleDeposit()}
            disabled={!isConnected || isLoading}
            className="shrink-0 whitespace-nowrap rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isLoading ? "处理中..." : "存款"}
          </button>
        </div>
      </section>

      <section className="rounded-2xl border border-emerald-200 bg-emerald-50/40 p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-zinc-900">通过签名存款</h2>
        <p className="mt-2 text-sm text-zinc-600">
          使用 EIP-2612 离线签名授权，只需 1 笔链上交易即可完成存款（无需先发送 approve
          交易）。请输入 Token 数量，然后点击按钮在钱包中签名并提交。
        </p>
        {!supportsPermit && isConnected ? (
          <p className="mt-3 text-sm text-amber-700">
            当前 Token 不支持 permit。请部署{" "}
            <code className="rounded bg-amber-100 px-1">MyPermitToken</code>{" "}
            并更新环境变量中的 Token 地址。
          </p>
        ) : null}
        <div className="mt-4 flex flex-col gap-3 sm:flex-row">
          <input
            type="text"
            inputMode="decimal"
            placeholder="例如 100"
            value={permitDepositAmount}
            onChange={(event) => setPermitDepositAmount(event.target.value)}
            disabled={!isConnected || isLoading || !supportsPermit}
            className="w-full rounded-lg border border-zinc-200 px-4 py-2.5 text-sm outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100 disabled:bg-zinc-50"
          />
          <button
            type="button"
            onClick={() => void handlePermitDeposit()}
            disabled={
              !isConnected ||
              isLoading ||
              !supportsPermit ||
              !permitDepositAmount.trim()
            }
            className="shrink-0 whitespace-nowrap rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-emerald-500 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isLoading ? "处理中..." : "签名并存款"}
          </button>
        </div>
      </section>

      <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-zinc-900">从 TokenBank 取款</h2>
        <p className="mt-2 text-sm text-zinc-500">
          合约会一次性取回你在 TokenBank 中的全部存款。
        </p>
        <div className="mt-4 flex flex-col gap-3 sm:flex-row">
          <input
            type="number"
            min="0"
            step="any"
            placeholder="取款金额"
            value={withdrawAmount}
            onChange={(event) => setWithdrawAmount(event.target.value)}
            disabled={!isConnected || isLoading}
            className="w-full rounded-lg border border-zinc-200 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-500 focus:ring-2 focus:ring-indigo-100 disabled:bg-zinc-50"
          />
          <button
            type="button"
            onClick={() => void handleWithdraw()}
            disabled={!isConnected || isLoading || bankDeposit === 0n}
            className="shrink-0 whitespace-nowrap rounded-lg border border-zinc-300 px-5 py-2.5 text-sm font-medium text-zinc-800 transition hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isLoading ? "处理中..." : "取款"}
          </button>
        </div>
      </section>

      {statusMessage ? (
        <p className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-3 text-sm text-zinc-700">
          {statusMessage}
        </p>
      ) : null}
    </div>
  );
}
