# NFTMarket Gas Report (v2 — 优化后)

> 生成日期：2026-06-03  
> Forge：`1.5.1-Homebrew`  
> 对比基线：[gas_report_v1.md](./gas_report_v1.md)

## 优化摘要

| 优化项 | 说明 |
|--------|------|
| Storage 打包 | `Listing` 由 3 slot（seller + price + active）改为 1 slot（`address` + `uint96 price`），用 `seller != 0` 表示已上架 |
| 去掉 `SafeERC20` | 已知 `MyToken` 为标准 ERC20，直接 `transfer` / `transferFrom` + `TransferFailed` |
| 上架用 `transferFrom` | 不再 `safeTransferFrom`，避免向本合约回调 `onERC721Received` |
| `_purchase` 读 storage | 用 `Listing storage` 替代 `memory` 拷贝；`delete` 只清 1 slot |
| Custom errors | 替代 `require` 字符串，降低 revert 与部署体积 |
| `permitBuy` | 移除冗余的二次 `whitelistedBuyers` 检查 |
| 构造函数 | 合并零地址校验为单次 `ZeroAddress` |

**破坏性变更**：`listings(tokenId)` 不再返回 `active`，请用 `seller != address(0)` 判断是否在售；`price` 链上类型为 `uint96`（上限约 7.9×10²⁷ wei，18 位小数下足够）。

## 执行命令

```bash
forge test --gas-report --match-path test/NFTMarket.t.sol
```

## 关键路径对比（`--gas-report` 测试总 gas）

| 测试用例 | v1 | v2 | 变化 |
|----------|-----|-----|------|
| `test_List_TransfersNftToMarket` | 211,302 | 159,763 | **−24%** |
| `test_BuyNFT_TransfersTokenAndNft` | 380,570 | 332,719 | **−13%** |
| `test_BuyNFTViaTransferAndCall` | 339,922 | 287,195 | **−16%** |
| `test_PermitBuy_WithSignatureBuysNft` | 449,534 | 412,180 | **−8%** |
| `test_RevertWhen_BuyNotListed` | 39,799 | 35,131 | **−12%** |

## NFTMarket 合约级对比

| 指标 | v1 | v2 |
|------|-----|-----|
| Deployment Cost | 2,224,426 | 2,075,176 |
| Deployment Size | 12,844 | 11,892 |
| `list` Median | 133,273 | 86,112 |
| `buyNft` Median | 59,672 | 51,866 |
| `listings` 读取 | 7,379 | 3,218 |

## 各测试用例 Gas（v2）

| 测试用例 | Gas | 结果 |
|----------|-----|------|
| `test_BuyNFTViaTransferAndCall` | 287,195 | PASS |
| `test_BuyNFT_MultipleListings` | 678,749 | PASS |
| `test_BuyNFT_TransfersTokenAndNft` | 332,719 | PASS |
| `test_Constructor` | 16,331 | PASS |
| `test_List_EmitsListedEvent` | 145,367 | PASS |
| `test_List_TransfersNftToMarket` | 159,763 | PASS |
| `test_PermitBuy_AlreadyWhitelistedSkipsSignature` | 422,362 | PASS |
| `test_PermitBuy_WithSignatureBuysNft` | 412,180 | PASS |
| `test_PermitWithBuyer_WhitelistsBuyer` | 116,594 | PASS |
| `test_RevertWhen_BuyNotListed` | 35,131 | PASS |
| `test_RevertWhen_BuyWithInsufficientBalance` | 510,474 | PASS |
| `test_RevertWhen_BuyWithoutTokenApproval` | 180,576 | PASS |
| `test_RevertWhen_ConstructorWithZeroAddresses` | 986,599 | PASS |
| `test_RevertWhen_ListNotOwner` | 39,635 | PASS |
| `test_RevertWhen_ListTwice` | 172,520 | PASS |
| `test_RevertWhen_ListWithZeroPrice` | 88,556 | PASS |
| `test_RevertWhen_ListWithoutApproval` | 48,888 | PASS |
| `test_RevertWhen_PermitBuy_NotWhitelistedWithoutValidSignature` | 311,236 | PASS |
| `test_RevertWhen_PermitBuy_WithoutWhitelistSignature` | 264,939 | PASS |
| `test_RevertWhen_PermitWithBuyer_ExpiredSignature` | 50,493 | PASS |
| `test_RevertWhen_PermitWithBuyer_InvalidSigner` | 79,016 | PASS |
| `test_RevertWhen_TransferAndCallNotListed` | 75,014 | PASS |
| `test_RevertWhen_TransferAndCallWithWrongPrice` | 212,918 | PASS |

## NFTMarket 函数 Gas（v2）

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| `buyNft` | 24,016 | 54,718 | 51,866 | 85,358 | 6 |
| `list` | 21,989 | 72,769 | 86,112 | 90,912 | 18 |
| `listings` | 3,218 | 3,218 | 3,218 | 3,218 | 2 |
| `permitBuy` | 25,315 | 75,149 | 69,787 | 135,710 | 4 |
| `permitWithBuyer` | 25,400 | 58,177 | 65,236 | 76,838 | 4 |
