# NFTMarket Gas Report (v1)

> 生成日期：2026-06-03  
> Forge：`1.5.1-Homebrew`  
> 测试文件：`test/NFTMarket.t.sol`（合约 `NFTMarketTest`）

## 执行命令

在 `foundry/` 目录下运行：

```bash
forge test --gas-report --match-path test/NFTMarket.t.sol
```

## 测试结果摘要

| 项目 | 值 |
|------|-----|
| 测试套件 | 1 |
| 通过 | 23 |
| 失败 | 0 |
| 跳过 | 0 |
| 套件耗时 | ~19 ms |

## 各测试用例 Gas

| 测试用例 | Gas | 结果 |
|----------|-----|------|
| `test_BuyNFTViaTransferAndCall` | 339,922 | PASS |
| `test_BuyNFT_MultipleListings` | 766,169 | PASS |
| `test_BuyNFT_TransfersTokenAndNft` | 380,570 | PASS |
| `test_Constructor` | 16,331 | PASS |
| `test_List_EmitsListedEvent` | 192,528 | PASS |
| `test_List_TransfersNftToMarket` | 211,302 | PASS |
| `test_PermitBuy_AlreadyWhitelistedSkipsSignature` | 464,614 | PASS |
| `test_PermitBuy_WithSignatureBuysNft` | 449,534 | PASS |
| `test_PermitWithBuyer_WhitelistsBuyer` | 116,594 | PASS |
| `test_RevertWhen_BuyNotListed` | 39,799 | PASS |
| `test_RevertWhen_BuyWithInsufficientBalance` | 567,097 | PASS |
| `test_RevertWhen_BuyWithoutTokenApproval` | 237,199 | PASS |
| `test_RevertWhen_ConstructorWithZeroAddresses` | 1,052,432 | PASS |
| `test_RevertWhen_ListNotOwner` | 39,934 | PASS |
| `test_RevertWhen_ListTwice` | 219,980 | PASS |
| `test_RevertWhen_ListWithZeroPrice` | 88,887 | PASS |
| `test_RevertWhen_ListWithoutApproval` | 48,940 | PASS |
| `test_RevertWhen_PermitBuy_NotWhitelistedWithoutValidSignature` | 358,397 | PASS |
| `test_RevertWhen_PermitBuy_WithoutWhitelistSignature` | 312,100 | PASS |
| `test_RevertWhen_PermitWithBuyer_ExpiredSignature` | 50,493 | PASS |
| `test_RevertWhen_PermitWithBuyer_InvalidSigner` | 79,016 | PASS |
| `test_RevertWhen_TransferAndCallNotListed` | 79,685 | PASS |
| `test_RevertWhen_TransferAndCallWithWrongPrice` | 264,566 | PASS |

## 合约级 Gas 汇总（`--gas-report`）

### `MartinNFT` (`src/MartinNFT.sol`)

| 指标 | 值 |
|------|-----|
| Deployment Cost | 2,241,578 |
| Deployment Size | 11,270 |

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| `approve` | 49,066 | 49,066 | 49,066 | 49,078 | 15 |
| `mint` | 152,114 | 184,889 | 186,314 | 186,314 | 24 |
| `ownerOf` | 3,049 | 3,049 | 3,049 | 3,049 | 24 |

### `MyToken` (`src/MyToken.sol`)

| 指标 | 值 |
|------|-----|
| Deployment Cost | 1,830,072 |
| Deployment Size | 9,975 |

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| `approve` | 46,985 | 46,985 | 46,985 | 46,985 | 8 |
| `balanceOf` | 2,873 | 2,873 | 2,873 | 2,873 | 15 |
| `transfer` | 35,045 | 51,461 | 52,145 | 52,145 | 50 |
| `transferAndCall` | 65,450 | 77,900 | 65,525 | 102,725 | 3 |

### `NFTMarket` (`src/NFTMarket.sol`)

| 指标 | 值 |
|------|-----|
| Deployment Cost | 2,224,426 |
| Deployment Size | 12,844 |

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| `NFT` | 636 | 636 | 636 | 636 | 1 |
| `PAYMENT_TOKEN` | 614 | 614 | 614 | 614 | 1 |
| `buyNft` | 28,599 | 60,041 | 59,672 | 84,911 | 6 |
| `hashBuyerPermit` | 4,005 | 4,005 | 4,005 | 4,005 | 6 |
| `list` | 22,238 | 109,491 | 133,273 | 138,073 | 18 |
| `listings` | 7,379 | 7,379 | 7,379 | 7,379 | 2 |
| `nonces` | 2,852 | 2,852 | 2,852 | 2,852 | 1 |
| `permitBuy` | 25,315 | 75,658 | 70,908 | 135,503 | 4 |
| `permitWithBuyer` | 25,400 | 58,177 | 65,236 | 76,838 | 4 |
| `whitelistedBuyers` | 2,856 | 2,856 | 2,856 | 2,856 | 2 |

## 说明

- **各测试用例 Gas**：单次 `forge test` 运行中该测试函数的总消耗（含 setUp 分摊等）。
- **合约级汇总**：测试期间对相关合约函数的调用统计；`Min/Avg/Median/Max` 为多次调用的分布，`# Calls` 为调用次数。
- 复现：在 `foundry/` 目录执行上文命令即可更新数据。
