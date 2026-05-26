import { assertConfig, config } from "./config.js";
import { TransferStore } from "./db.js";
import { TransferIndexer } from "./indexer.js";
import { createServer } from "./server.js";

async function main() {
  assertConfig();

  const store = new TransferStore(config.databasePath);
  const indexer = new TransferIndexer(config.tokenAddress!, store);
  const app = createServer(store);

  await indexer.syncHistorical();
  indexer.startLiveWatch();

  const server = app.listen(config.port, () => {
    console.log(`REST API 已启动: http://127.0.0.1:${config.port}`);
    console.log(
      `查询示例: GET /api/transfers/0x...?direction=all&limit=20&offset=0`,
    );
  });

  const shutdown = () => {
    console.log("\n正在关闭 backend...");
    indexer.stop();
    server.close(() => {
      store.close();
      process.exit(0);
    });
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
