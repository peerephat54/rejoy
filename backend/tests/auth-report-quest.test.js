const assert = require("node:assert/strict");
const test = require("node:test");
const mongoose = require("mongoose");
const request = require("supertest");
const { MongoMemoryServer } = require("mongodb-memory-server");

process.env.JWT_SECRET =
  process.env.JWT_SECRET || "test-secret-that-is-long-enough-for-rejoy-jwt";
process.env.JWT_EXPIRES_IN = "30s";
process.env.REFRESH_TOKEN_EXPIRES_DAYS = "1";
process.env.CORS_ORIGIN = "*";

const app = require("../src/app");

let mongo;

test.before(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
});

test.after(async () => {
  await mongoose.disconnect();
  await mongo.stop();
});

async function register(email) {
  const response = await request(app)
    .post("/api/auth/register")
    .send({
      email,
      password: "password123",
      firstName: email.split("@")[0],
      surname: "Tester",
      age: 18,
    })
    .expect(201);

  assert.ok(response.body.token);
  assert.ok(response.body.refreshToken);
  assert.equal(response.body.user.email, email);
  return response.body;
}

test("auth supports refresh token rotation", async () => {
  const auth = await register("refresh-a@example.com");

  const refreshed = await request(app)
    .post("/api/auth/refresh")
    .send({ refreshToken: auth.refreshToken })
    .expect(200);

  assert.ok(refreshed.body.token);
  assert.ok(refreshed.body.refreshToken);
  assert.notEqual(refreshed.body.refreshToken, auth.refreshToken);

  await request(app)
    .post("/api/auth/refresh")
    .send({ refreshToken: auth.refreshToken })
    .expect(401);
});

test("users cannot read or mutate another user report", async () => {
  const userA = await register("owner-a@example.com");
  const userB = await register("owner-b@example.com");

  const report = await request(app)
    .post("/api/reports")
    .set("Authorization", `Bearer ${userA.token}`)
    .send({
      dailyMood: "calm",
      diaryNote: "A private note",
      phq9Score: 4,
      userId: userA.user._id,
    })
    .expect(201);

  await request(app)
    .get(`/api/reports/${report.body._id}`)
    .set("Authorization", `Bearer ${userB.token}`)
    .expect(403);

  await request(app)
    .patch(`/api/reports/${report.body._id}`)
    .set("Authorization", `Bearer ${userB.token}`)
    .send({ diaryNote: "B should not edit this" })
    .expect(403);
});

test("quest finish is scoped to the authenticated user", async () => {
  const userA = await register("quest-a@example.com");
  const userB = await register("quest-b@example.com");

  await request(app)
    .post(`/api/users/${userA.user._id}/quest-day/finish`)
    .set("Authorization", `Bearer ${userB.token}`)
    .send({
      selected_quests: ["Breathe", "Water", "Kind note"],
      completed_quests: ["Breathe", "Water", "Kind note"],
      completion_rate: "3/3",
    })
    .expect(403);

  const finish = await request(app)
    .post(`/api/users/${userA.user._id}/quest-day/finish`)
    .set("Authorization", `Bearer ${userA.token}`)
    .send({
      selected_quests: ["Breathe", "Water", "Kind note"],
      completed_quests: ["Breathe", "Water", "Kind note"],
      completion_rate: "3/3",
    })
    .expect(201);

  assert.equal(finish.body.completed_quests_count, 3);
});

test("quest day uses zero-disappointment animal encounters", async () => {
  const auth = await register("encounter-a@example.com");
  const userId = auth.user._id;
  const questSet = ["หายใจช้า ๆ", "ดื่มน้ำ", "เขียนประโยคใจดี"];

  const firstFinish = await request(app)
    .post(`/api/users/${userId}/quest-day/finish`)
    .set("Authorization", `Bearer ${auth.token}`)
    .send({
      selected_quests: questSet,
      completed_quests: questSet,
      completion_rate: "3/3",
    })
    .expect(201);

  assert.equal(firstFinish.body.unlocked_animals_today.length, 1);
  assert.ok(firstFinish.body.companion_message);

  const secondFinish = await request(app)
    .post(`/api/users/${userId}/quest-day/finish`)
    .set("Authorization", `Bearer ${auth.token}`)
    .send({
      selected_quests: ["เปิดม่าน", "ล้างหน้า", "เดิน 2 นาที"],
      completed_quests: ["เปิดม่าน", "ล้างหน้า", "เดิน 2 นาที"],
      completion_rate: "3/3",
    })
    .expect(201);

  assert.equal(secondFinish.body.unlocked_animals_today.length, 1);
  assert.notEqual(
    firstFinish.body.unlocked_animals_today[0],
    secondFinish.body.unlocked_animals_today[0],
  );

  await request(app)
    .post(`/api/users/${userId}/positive-memory`)
    .set("Authorization", `Bearer ${auth.token}`)
    .send({
      prompt: "วันนี้ผ่านอะไรมาได้บ้าง",
      answer: "ฉันลุกมาดื่มน้ำได้",
      mood_state: "tired",
    })
    .expect(201);
});

test("quest write endpoints require authentication", async () => {
  await request(app)
    .post("/api/quests")
    .send({
      name: "Unauthorized quest",
      description: "Should not be created",
      energyLevel: "low",
    })
    .expect(401);

  const fakeId = new mongoose.Types.ObjectId().toString();
  await request(app)
    .patch(`/api/quests/${fakeId}`)
    .send({ name: "Changed" })
    .expect(401);

  await request(app).delete(`/api/quests/${fakeId}`).expect(401);
});

test("deep health is hidden in production without health key", async () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalHealthKey = process.env.HEALTH_CHECK_KEY;
  process.env.NODE_ENV = "production";
  process.env.HEALTH_CHECK_KEY = "test-health-key";

  await request(app).get("/api/health/deep").expect(404);

  await request(app)
    .get("/api/health/deep")
    .set("x-health-check-key", "test-health-key")
    .expect(200);

  if (originalNodeEnv === undefined) {
    delete process.env.NODE_ENV;
  } else {
    process.env.NODE_ENV = originalNodeEnv;
  }

  if (originalHealthKey === undefined) {
    delete process.env.HEALTH_CHECK_KEY;
  } else {
    process.env.HEALTH_CHECK_KEY = originalHealthKey;
  }
});

test("clinical dashboard summarizes own patient risk without diary text", async () => {
  const auth = await register("clinical-owner@example.com");

  await request(app)
    .post("/api/reports")
    .set("Authorization", `Bearer ${auth.token}`)
    .send({
      dailyMood: "heavy",
      diaryNote: "This private text should not appear in dashboard",
      phq9Score: 22,
      cbtCompletionRate: "1/5",
      isSosTriggered: true,
      symptomMatrix: {
        mood_score: 8,
        somatic_score: 6,
        behavioral_score: 7,
      },
    })
    .expect(201);

  const dashboard = await request(app)
    .get("/api/clinical/dashboard")
    .set("Authorization", `Bearer ${auth.token}`)
    .expect(200);

  assert.equal(dashboard.body.scope, "self-demo");
  assert.equal(dashboard.body.totals.patients, 1);
  assert.equal(dashboard.body.patients[0].riskStatus, "Urgent");
  assert.equal(dashboard.body.privacy.diaryTextHidden, true);
  assert.equal(JSON.stringify(dashboard.body).includes("private text"), false);
});

test("clinical alert queue and care plans are scoped safely", async () => {
  const userA = await register("care-owner@example.com");
  const userB = await register("care-other@example.com");

  await request(app)
    .post(`/api/users/${userA.user._id}/phq9-history`)
    .set("Authorization", `Bearer ${userA.token}`)
    .send({ total_score: 21 })
    .expect(201);

  const alerts = await request(app)
    .get("/api/clinical/alerts")
    .set("Authorization", `Bearer ${userA.token}`)
    .expect(200);

  assert.ok(alerts.body.alerts.some((alert) => alert.type === "PHQ9_HIGH"));

  await request(app)
    .post("/api/clinical/care-plans")
    .set("Authorization", `Bearer ${userB.token}`)
    .send({
      userId: userA.user._id,
      title: "Try low energy routine",
      focusArea: "activity",
    })
    .expect(403);

  const created = await request(app)
    .post("/api/clinical/care-plans")
    .set("Authorization", `Bearer ${userA.token}`)
    .send({
      title: "Try low energy routine",
      focusArea: "activity",
      recommendedQuestEnergy: "low",
      note: "Start with one gentle quest.",
    })
    .expect(201);

  assert.equal(created.body.carePlan.title, "Try low energy routine");

  const plans = await request(app)
    .get("/api/clinical/care-plans")
    .set("Authorization", `Bearer ${userA.token}`)
    .expect(200);

  assert.equal(plans.body.carePlans.length, 1);
});
