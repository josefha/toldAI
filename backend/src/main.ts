import { readConfig } from "./config.js";
import { Store } from "./store.js";
import { Providers } from "./providers.js";
import { createAPI } from "./api.js";
import { Worker } from "./worker.js";
const config = readConfig();
const store = new Store(config);
const providers = new Providers(config);
const app = await createAPI(config, store, providers);
const worker = new Worker(store, providers, config, (message) =>
  app.log.warn(message),
);
await app.listen({ port: config.PORT, host: config.HOST });
const running =
  config.WORKER_ENABLED === "true" ? worker.run() : Promise.resolve();
async function close() {
  worker.stop();
  await app.close();
  await running;
  process.exit(0);
}
process.on("SIGTERM", () => void close());
process.on("SIGINT", () => void close());
