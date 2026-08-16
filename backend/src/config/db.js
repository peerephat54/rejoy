const mongoose = require("mongoose");

let connectionPromise = null;
let listenersAttached = false;

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
    minPoolSize: readPositiveInt("MONGODB_MIN_POOL_SIZE", 0, {
      min: 0,
      max: 20,
    }),
    maxConnecting: readPositiveInt("MONGODB_MAX_CONNECTING", 2, {
      min: 1,
      max: 10,
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

function attachConnectionListeners() {
  if (listenersAttached) {
    return;
  }

  listenersAttached = true;

  mongoose.connection.on("connected", () => {
    const { maxPoolSize, minPoolSize, maxConnecting } = getMongoPoolConfig();
    console.log(
      `MongoDB connected (pool min=${minPoolSize}, max=${maxPoolSize}, connecting=${maxConnecting})`,
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
}

async function connectDB(uri) {
  if (!uri) {
    throw new Error("MONGODB_URI is missing");
  }

  mongoose.set("strictQuery", true);
  mongoose.set("bufferCommands", false);
  mongoose.set("autoIndex", process.env.NODE_ENV !== "production");

  attachConnectionListeners();

  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (connectionPromise) {
    return connectionPromise;
  }

  connectionPromise = mongoose.connect(uri, {
    ...getMongoPoolConfig(),
    retryWrites: true,
    serverApi: { version: "1", strict: false, deprecationErrors: false },
  });

  try {
    await connectionPromise;
    return mongoose.connection;
  } finally {
    // Only deduplicate concurrent connection attempts. Keeping a resolved
    // promise here would prevent a later reconnect after a full disconnect.
    connectionPromise = null;
  }
}

async function disconnectDB() {
  connectionPromise = null;
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
}

function isDatabaseReady() {
  return mongoose.connection.readyState === 1;
}

module.exports = {
  connectDB,
  disconnectDB,
  getMongoPoolConfig,
  isDatabaseReady,
};
