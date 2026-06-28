source .env

cast send 0x4200000000000000000000000000000000000012 \
  "createOptimismMintableERC20(address,string,string)" \
  "0x2d5052c008CFCCe8F0E18C1F35B296a367872f12" \
  "MyToken" \
  "MTK" \
  --rpc-url https://base-sepolia-rpc.publicnode.com  \
  --account deployer_1

#L1  Sepolia  MyToken address: 0x2d5052c008CFCCe8F0E18C1F35B296a367872f12
#L2  Base Sepolia  MyToken address: 0x98a49b93f5fe2c3b57f05596f6a857b0a8f4ee71