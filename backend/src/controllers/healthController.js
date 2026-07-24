const mongoose = require("mongoose");
const Quest = require("../models/Quest");
const { getMongoPoolConfig } = require("../config/db");
const { getGeminiConfig } = require("./chatController");

function getHealth(req, res) {
  res.json({
    status: "ok",
    service: "rejoy-backend",
    database:
      mongoose.connection.readyState === 1 ? "connected" : "disconnected",
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
  });
}

async function getDeepHealth(req, res, next) {
  try {
    const dbReady = mongoose.connection.readyState === 1;
    const [questCount, dbPing] = await Promise.all([
      dbReady ? Quest.countDocuments({ isActive: true }) : Promise.resolve(0),
      dbReady ? mongoose.connection.db.admin().ping() : Promise.resolve(null),
    ]);

    const gemini = getGeminiConfig();

    res.json({
      status: dbReady ? "ok" : "degraded",
      service: "rejoy-backend",
      database: dbReady ? "connected" : "disconnected",
      dbPingOk: dbPing?.ok === 1,
      activeQuestCount: questCount,
      questSeedReady: questCount >= 10,
      geminiConfigured: gemini.configured,
      geminiModel: gemini.model,
      mongoPool: getMongoPoolConfig(),
      nodeEnv: process.env.NODE_ENV || "development",
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.round(process.uptime()),
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = { getDeepHealth, getHealth };
