const mongoose = require("mongoose");

function readPositiveInt(name, fallback, { min = 0, max = 120000 } = {}) {
  const raw = process.env[name];
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < min) {
    return fallback;
  }
  return Math.min(parsed, max);
}

function getMongoPoolConfig() {
  return {
    maxPoolSize: readPositiveInt("MONGODB_MAX_POOL_SIZE", 10, {
      min: 1,
      max: 100,
    }),
    minPoolSize: readPositiveInt("MONGODB_MIN_POOL_SIZE", 1, {
      min: 0,
      max: 20,
    }),
    maxIdleTimeMS: readPositiveInt("MONGODB_MAX_IDLE_TIME_MS", 60000, {
      min: 1000,
      max: 600000,
    }),
    waitQueueTimeoutMS: readPositiveInt("MONGODB_WAIT_QUEUE_TIMEOUT_MS", 5000, {
      min: 500,
      max: 60000,
    }),
    serverSelectionTimeoutMS: readPositiveInt(
      "MONGODB_SERVER_SELECTION_TIMEOUT_MS",
      8000,
      { min: 1000, max: 60000 },
    ),
    socketTimeoutMS: readPositiveInt("MONGODB_SOCKET_TIMEOUT_MS", 30000, {
      min: 5000,
      max: 120000,
    }),
    connectTimeoutMS: readPositiveInt("MONGODB_CONNECT_TIMEOUT_MS", 10000, {
      min: 1000,
      max: 60000,
    }),
    heartbeatFrequencyMS: readPositiveInt(
      "MONGODB_HEARTBEAT_FREQUENCY_MS",
      10000,
      { min: 2000, max: 60000 },
    ),
  };
}

async function connectDB(uri) {
  if (!uri) {
    throw new Error("MONGODB_URI is missing");
  }

  mongoose.set("strictQuery", true);
  mongoose.set("bufferCommands", false);

  mongoose.connection.on("connected", () => {
    const { maxPoolSize, minPoolSize } = getMongoPoolConfig();
    console.log(
      `MongoDB connected (pool min=${minPoolSize}, max=${maxPoolSize})`,
    );
  });

  mongoose.connection.on("disconnected", () => {
    console.warn("MongoDB disconnected");
  });

  mongoose.connection.on("reconnected", () => {
    console.log("MongoDB reconnected");
  });

  mongoose.connection.on("error", (error) => {
    console.error("MongoDB connection error:", error.message);
  });

  await mongoose.connect(uri, {
    ...getMongoPoolConfig(),
    retryWrites: true,
  });
}

module.exports = { connectDB, getMongoPoolConfig };
