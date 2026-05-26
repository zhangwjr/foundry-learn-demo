# 将 MyToken 部署到 Sepolia 测试网

本文档记录使用 Foundry 将 `src/MyToken.sol` 部署到 [Sepolia Etherscan](https://sepolia.etherscan.io/) 并完成合约验证的完整流程。

## 流程概览

```mermaid
flowchart LR
    A[准备环境] --> B[编写部署脚本]
    B --> C[配置 foundry.toml]
    C --> D[配置 .env]
    D --> E[领取 Sepolia ETH]
    E --> F[本地编译测试]
    F --> G[forge script 部署]
    G --> H[Etherscan 自动验证]
    H --> I[浏览器查看合约]
```

## 前置条件

- 已安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)（`forge`、`cast`、`anvil`）
- 已安装 [MetaMask](https://metamask.io/) 钱包
- 项目中已安装 OpenZeppelin 依赖：

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

- 项目根目录存在 `remappings.txt`（供 IDE 解析 `@openzeppelin/contracts` 导入）：

```bash
forge remappings > remappings.txt
```

## 第 1 步：确认合约代码

`MyToken.sol` 基于 OpenZeppelin 的 `ERC20` 和 `Ownable` 实现：

- 代币名称：`MyToken`
- 代币符号：`MTK`
- 初始供应量：1,000,000 MTK
- 构造函数接收 `initialOwner`，部署时将全部初始代币铸造给 owner
- 仅 owner 可调用 `mint()` 增发

## 第 2 步：编写部署脚本

创建 `script/MyToken.s.sol`：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        new MyToken(deployer);

        vm.stopBroadcast();
    }
}
```

说明：

- 从 `.env` 读取 `PRIVATE_KEY`
- 将部署者地址作为 `initialOwner` 传入构造函数
- `vm.startBroadcast()` 会向 Sepolia 发送真实交易

## 第 3 步：配置 foundry.toml

在 `foundry.toml` 中添加 Sepolia RPC 与 Etherscan 验证配置：

```toml
[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
```

## 第 4 步：配置环境变量

复制模板并创建 `.env`：

```bash
cp .env.example .env
```

填写以下三项：

```env
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
PRIVATE_KEY=0x你的钱包私钥
ETHERSCAN_API_KEY=你的Etherscan_API_Key
```

### 4.1 获取 PRIVATE_KEY

1. 打开 MetaMask
2. 选择要用于部署的账户
3. 进入 **账户详情 → 导出私钥**
4. 粘贴到 `.env` 的 `PRIVATE_KEY`

注意：

- **同一个账户在所有 EVM 网络（主网、Sepolia 等）共用同一个私钥和地址**
- 私钥必须以 `0x` 开头，否则 Foundry 会报错
- **切勿**将 `.env` 提交到 Git（项目已在 `.gitignore` 中忽略）

### 4.2 获取 ETHERSCAN_API_KEY

1. 注册并登录 [etherscan.io](https://etherscan.io)
2. 打开 [etherscan.io/myapikey](https://etherscan.io/myapikey)
3. 点击 **Add** 创建 API Key
4. 将 Key 填入 `.env`

该 API Key 可用于主网和 Sepolia 等 Etherscan 系浏览器。

## 第 5 步：准备 Sepolia 测试 ETH

部署需要支付 Gas，请确保部署地址在 Sepolia 上有测试 ETH：

1. MetaMask 切换到 **Sepolia** 网络
2. 从水龙头领取测试 ETH，例如：
   - [Alchemy Sepolia Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
   - [Google Cloud Sepolia Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)

## 第 6 步：本地编译与测试（推荐）

```bash
forge build
forge test --match-contract MyTokenTest
```

可选：在本地 Anvil 上模拟部署，确认脚本无误：

```bash
# 终端 1
anvil

# 终端 2
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/MyToken.s.sol:MyTokenScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

## 第 7 步：部署到 Sepolia 并验证

执行以下命令：

```bash
forge script script/MyToken.s.sol:MyTokenScript \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  -vvvv
```

参数说明：

| 参数 | 作用 |
|------|------|
| `--rpc-url sepolia` | 使用 `foundry.toml` 中配置的 Sepolia RPC |
| `--broadcast` | 实际发送链上交易（不加则仅模拟） |
| `--verify` | 部署后自动在 Etherscan 上验证源码 |
| `-vvvv` | 输出详细日志，便于排查问题 |

成功后会看到类似输出：

```text
ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Contract successfully verified
```

终端会输出合约地址，例如：

```text
https://sepolia.etherscan.io/address/0x你的合约地址
```

## 第 8 步：在 Etherscan 上查看

打开 Sepolia Etherscan 上的合约地址页面，可查看：

- **Transactions**：部署交易记录
- **Contract → Code**：已验证的 Solidity 源码
- **Contract → Read Contract**：读取 `name`、`symbol`、`totalSupply`、`balanceOf` 等
- **Contract → Write Contract**：连接钱包后调用 `mint`、`transfer` 等

## 第 9 步：在 MetaMask 中添加代币（可选）

1. MetaMask 切换到 Sepolia 网络
2. 点击 **导入代币**
3. 填入部署得到的合约地址
4. 符号 `MTK`、小数 `18` 通常会自动识别

## 常见问题

### 1. `missing hex prefix ("0x") for hex string`

`.env` 中的 `PRIVATE_KEY` 缺少 `0x` 前缀。正确格式：

```env
PRIVATE_KEY=0xabc123...
```

### 2. `insufficient funds for gas`

部署地址 Sepolia ETH 不足，请从水龙头领取后再部署。

### 3. `Source "@openzeppelin/contracts/..." not found`

IDE 报错时，在项目根目录生成 `remappings.txt`：

```bash
forge remappings > remappings.txt
```

Foundry 编译本身不受影响。

### 4. Etherscan 验证 Pending 较久

属正常现象，Foundry 会自动轮询；通常几十秒内会显示 **Pass - Verified**。

## 本次部署记录（示例）

| 项目 | 值 |
|------|-----|
| 合约地址 | `0xCeAC3d2F5437E7dd941e0b5B23ba3Cae9dD960b3` |
| 网络 | Sepolia |
| Etherscan | [查看合约](https://sepolia.etherscan.io/address/0xceac3d2f5437e7dd941e0b5b23ba3cae9dd960b3) |

## 相关文件

| 文件 | 说明 |
|------|------|
| `src/MyToken.sol` | ERC20 代币合约 |
| `script/MyToken.s.sol` | 部署脚本 |
| `foundry.toml` | RPC 与 Etherscan 配置 |
| `.env` | 私钥与 API Key（本地专用，勿提交） |
| `.env.example` | 环境变量模板 |
| `remappings.txt` | 依赖路径映射 |
| `broadcast/MyToken.s.sol/11155111/` | 部署交易记录 |

## 参考链接

- [Foundry Book - Deploying](https://book.getfoundry.sh/forge/deploying)
- [Foundry Book - Verifying](https://book.getfoundry.sh/forge/deploying#verifying)
- [Sepolia Etherscan](https://sepolia.etherscan.io/)
- [Etherscan API Keys](https://etherscan.io/myapikey)
