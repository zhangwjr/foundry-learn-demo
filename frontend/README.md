# TokenBank Frontend

Next.js + viem 前端，用于与 TokenBank 合约交互。

## 环境变量

复制 `.env.example` 为 `.env.local` 并填写部署后的合约地址：

```bash
cp .env.example .env.local
```

## 本地开发

1. 启动 Anvil 本地链：

```bash
anvil
```

2. 部署合约：

```bash
forge script script/DeployTokenBank.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

3. 将部署输出的 `MyToken` 和 `TokenBank` 地址写入 `frontend/.env.local`

4. 启动前端：

```bash
cd frontend
npm run dev
```

5. 在 MetaMask 中导入 Anvil 默认账户，并添加本地网络（chain id: 31337, RPC: http://127.0.0.1:8545）

## 功能

- 右上角连接/断开钱包
- 展示钱包 Token 余额与 TokenBank 存款
- 输入金额存款（自动 approve + deposit）
- 从 TokenBank 取款（合约会一次性取回全部存款）
