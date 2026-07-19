require("dotenv").config();

const app = require("./app");
const { connectDB } = require("./config/db");
const { seedDefaultQuests } = require("./seed/defaultData");
const { listenWithFriendlyErrors } = require("./utils/serverListener");

const port = process.env.PORT || 3000;

async function bootstrap() {
  try {
    await connectDB(process.env.MONGODB_URI);
    await seedDefaultQuests();
    listenWithFriendlyErrors(app, port);
  } catch (error) {
    console.error("MongoDB connection failed:", error.message);
    process.exitCode = 1;
  }
}

bootstrap();
