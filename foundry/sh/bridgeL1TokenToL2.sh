source .env

# approve L1 bridge
# 批准 L1 桥合约转移你的代币
cast send 0x2d5052c008CFCCe8F0E18C1F35B296a367872f12 \
  "approve(address,uint256)" \
  "0xfd0bf71f60660e2f608ed56e1659c450eb113120" \
  "1000000000000000000000" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account deployer_1

# bridge L1 Token to L2
cast send 0xfd0bf71f60660e2f608ed56e1659c450eb113120 \
  "bridgeERC20(address,address,uint256,uint32,bytes)" \
  "0x2d5052c008CFCCe8F0E18C1F35B296a367872f12" \
  "0x98a49b93f5fe2c3b57f05596f6a857b0a8f4ee71" \
  "100000000000000" \
  "1000000" \
  "0x" \
  --rpc-url $SEPOLIA_RPC_URL \
  --account deployer_1
