require("dotenv").config();

const app = require("./app");
const { connectDB, disconnectDB } = require("./config/db");
const { seedDefaultQuests } = require("./seed/defaultData");
const { listenWithFriendlyErrors } = require("./utils/serverListener");

const port = process.env.PORT || 3000;
let server = null;
let shuttingDown = false;

async function shutdown(signal, exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received; draining active requests...`);

  const forceTimer = setTimeout(() => {
    console.error("Graceful shutdown timed out; forcing exit");
    process.exit(1);
  }, Number(process.env.SHUTDOWN_TIMEOUT_MS || 10000));
  forceTimer.unref();

  try {
    if (server) {
      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
        if (typeof server.closeIdleConnections === "function") {
          server.closeIdleConnections();
        }
      });
    }
    await disconnectDB();
    clearTimeout(forceTimer);
    process.exit(exitCode);
  } catch (error) {
    console.error("Graceful shutdown failed:", error.message);
    clearTimeout(forceTimer);
    process.exit(1);
  }
}

async function bootstrap() {
  try {
    await connectDB(process.env.MONGODB_URI);
    await seedDefaultQuests();
    server = listenWithFriendlyErrors(app, port);
  } catch (error) {
    console.error("MongoDB connection failed:", error.message);
    process.exitCode = 1;
  }
}

process.once("SIGTERM", () => shutdown("SIGTERM"));
process.once("SIGINT", () => shutdown("SIGINT"));
process.on("unhandledRejection", (error) => {
  console.error("Unhandled promise rejection:", error);
  shutdown("unhandledRejection", 1);
});
process.on("uncaughtException", (error) => {
  console.error("Uncaught exception:", error);
  shutdown("uncaughtException", 1);
});

bootstrap();
