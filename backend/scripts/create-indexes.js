require("dotenv").config();

const { connectDB, disconnectDB } = require("../src/config/db");
const Quest = require("../src/models/Quest");
const Report = require("../src/models/Report");
const User = require("../src/models/User");

async function createIndexes() {
  await connectDB(process.env.MONGODB_URI);

  const models = [User, Report, Quest];
  for (const model of models) {
    await model.createIndexes();
    console.log(`${model.modelName} indexes are ready`);
  }
}

createIndexes()
  .catch((error) => {
    console.error("Index creation failed:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await disconnectDB();
  });
