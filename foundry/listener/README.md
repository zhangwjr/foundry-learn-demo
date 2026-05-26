# NFTMarket Event Listener

使用 [viem](https://viem.sh) 监听 NFTMarket 合约的上架与成交事件，并在控制台打印日志。

## 监听事件

| 事件 | 触发函数 | 说明 |
|------|----------|------|
| `Listed` | `list` | NFT 上架 |
| `Sold` | `buyNft` / `onTransferReceived` | NFT 成交（普通购买或 transferAndCall） |

## 使用步骤

1. 启动 Anvil：

```bash
anvil
```

2. 部署 NFTMarket：

```bash
cd foundry
forge script script/DeployNFTMarket.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

3. 配置监听环境变量：

```bash
cd foundry/listener
cp .env.example .env
# 编辑 .env，填入 NFTMarket 合约地址
```

4. 安装依赖并启动监听：

```bash
npm install
npm run listen
```

5. 在另一个终端触发上架或购买，监听器会打印类似日志：

```text
[2026-05-22T08:00:00.000Z] NFT 上架 | tx=0x... | block=2 | seller=0x... | tokenId=0 | price=100 MTK
[2026-05-22T08:00:05.000Z] NFT 成交 | tx=0x... | block=3 | seller=0x... | buyer=0x... | tokenId=0 | price=100 MTK
```

按 `Ctrl+C` 停止监听。
