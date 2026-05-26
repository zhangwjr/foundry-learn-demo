# Backend

使用 [viem](https://viem.sh) 索引 MyToken 的 `Transfer` 事件并写入 SQLite，同时提供 REST API 按地址查询转账记录。

## 功能

- 启动时按区块批量回填历史 `Transfer` 事件
- 持续监听链上新 `Transfer` 事件
- `GET /api/transfers/:address` 查询某地址相关转账（转入 / 转出 / 全部）

## 使用步骤

1. 启动 Anvil 并部署 MyToken（或使用已有地址）：

```bash
anvil
```

```bash
cd foundry
forge script script/DeployTokenBank.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

2. 配置环境变量：

```bash
cd backend
cp .env.example .env
# 编辑 .env，填入 TOKEN_ADDRESS
```

3. 安装依赖并启动：

```bash
npm install
npm start
```

服务默认监听 `http://127.0.0.1:3001`。

## API

### 健康检查

```http
GET /health
```

### 查询转账记录

```http
GET /api/transfers/:address?direction=all&limit=20&offset=0
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `direction` | `all` / `in` / `out` | `all` |
| `limit` | 每页条数，最大 100 | `20` |
| `offset` | 偏移量 | `0` |

响应示例：

```json
{
  "address": "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
  "total": 2,
  "limit": 20,
  "offset": 0,
  "transfers": [
    {
      "txHash": "0x...",
      "logIndex": 0,
      "blockNumber": 2,
      "from": "0x...",
      "to": "0x...",
      "value": "1000000000000000000",
      "direction": "out"
    }
  ]
}
```

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `RPC_URL` | 链 RPC 地址 | `http://127.0.0.1:8545` |
| `CHAIN_ID` | 链 ID | `31337` |
| `TOKEN_ADDRESS` | MyToken 合约地址 | 必填 |
| `START_BLOCK` | 首次索引起始区块 | `0` |
| `PORT` | HTTP 端口 | `3001` |
| `DATABASE_PATH` | SQLite 文件路径 | `./data/transfers.db` |
| `INDEX_BATCH_SIZE` | 历史索引每批区块数 | `2000` |
