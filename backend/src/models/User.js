const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const { Schema } = mongoose;

const moodCheckinSchema = new Schema(
  {
    mood_level: { type: Number, required: true, min: 0, max: 10 },
    date: { type: Date, default: Date.now },
  },
  { _id: false },
);

const phq9LogSchema = new Schema(
  {
    total_score: { type: Number, required: true, min: 0, max: 27 },
    date: { type: Date, default: Date.now },
  },
  { _id: false },
);

const matrixLogSchema = new Schema(
  {
    date: { type: Date, default: Date.now },
    mood_score: { type: Number, default: 0 },
    somatic_score: { type: Number, default: 0 },
    behavioral_score: { type: Number, default: 0 },
  },
  { _id: false },
);

const questLogSchema = new Schema(
  {
    date: { type: Date, default: Date.now },
    energy_mode_selected: { type: String, default: "rest" },
    selected_quests: [{ type: String }],
    completed_quests: [{ type: String }],
    total_selected_quests: { type: Number, default: 0 },
    completed_quests_count: { type: Number, default: 0 },
    completion_rate: { type: String, default: "0%" },
    is_rest_day: { type: Boolean, default: false },
  },
  { _id: false },
);

const sosLogSchema = new Schema(
  {
    date: { type: Date, default: Date.now },
    trigger_source: { type: String, required: true },
    notes: { type: String, default: "" },
  },
  { _id: false },
);

const animalEncounterSchema = new Schema(
  {
    date: { type: Date, default: Date.now },
    animalId: { type: String, required: true, trim: true },
    animalName: { type: String, default: "", trim: true },
    trigger: { type: String, default: "quest_day_finish", trim: true },
    effortCount: { type: Number, default: 0 },
    moodState: { type: String, default: "", trim: true },
    message: { type: String, default: "" },
  },
  { _id: false },
);

const positiveMemorySchema = new Schema(
  {
    date: { type: Date, default: Date.now },
    prompt: { type: String, default: "" },
    answer: { type: String, required: true },
    animalId: { type: String, default: "", trim: true },
    moodState: { type: String, default: "", trim: true },
  },
  { _id: false },
);

const carePlanSchema = new Schema(
  {
    title: { type: String, required: true, trim: true },
    focusArea: {
      type: String,
      enum: ["sleep", "activity", "grounding", "medication", "follow_up", "general"],
      default: "general",
    },
    note: { type: String, default: "", trim: true },
    recommendedQuestEnergy: {
      type: String,
      enum: ["low", "medium", "high", "rest"],
      default: "low",
    },
    assignedBy: { type: Schema.Types.ObjectId, ref: "User", default: null },
    status: {
      type: String,
      enum: ["active", "completed", "paused"],
      default: "active",
    },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: true },
);

const refreshTokenSchema = new Schema(
  {
    tokenHash: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
  },
  { _id: false },
);

const userSchema = new Schema(
  {
    firstName: { type: String, required: true, trim: true },
    surname: { type: String, required: true, trim: true },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      unique: true,
      sparse: true,
      match: [/^\S+@\S+\.\S+$/, "Invalid email address"],
    },
    passwordHash: { type: String, select: false },
    age: { type: Number, required: true, min: 0, max: 120 },
    allergies: [{ type: String, trim: true }],
    phq9Score: { type: Number, default: 0, min: 0, max: 27 },
    medicalHistory: { type: String, default: "" },
    emergencyContactNumbers: [{ type: String, trim: true }],
    currentMedications: [{ type: String, trim: true }],
    symptomClusteringMatrix: [{ type: String, trim: true }],
    behavioralActivationTracking: {
      questCompletionRate: { type: String, default: "0%" },
      restingButtonStats: { type: String, default: "0" },
    },
    currentEnergyLevel: { type: String, default: "rest" },
    dailyMoodCheckin: { type: String, default: "" },
    selectedQuestsToday: [{ type: String, trim: true }],
    completedQuestsToday: [{ type: String, trim: true }],
    completedQuestsCount: { type: Number, default: 0 },
    unlockedAnimals: [{ type: String, trim: true }],
    unlockedAnimalToday: { type: String, default: "" },
    animalNicknames: { type: Map, of: String, default: {} },
    animalEncounterHistory: [animalEncounterSchema],
    positiveMemoryBank: [positiveMemorySchema],
    companionMirrorState: {
      animalId: { type: String, default: "" },
      moodState: { type: String, default: "" },
      supportMessage: { type: String, default: "" },
      updatedAt: { type: Date, default: null },
    },
    currentIslandWeather: { type: String, default: "sunny" },
    authProvider: {
      type: String,
      enum: ["google", "guest", "email"],
      default: "guest",
    },
    role: {
      type: String,
      enum: ["patient", "doctor", "psychologist", "admin"],
      default: "patient",
    },
    assignedClinicianIds: [{ type: Schema.Types.ObjectId, ref: "User" }],
    carePlans: [carePlanSchema],
    onboardingComplete: { type: Boolean, default: false },
    privacyConsentAcceptedAt: { type: Date, default: null },
    refreshTokens: [refreshTokenSchema],
    moodLog: [moodCheckinSchema],
    phq9History: [phq9LogSchema],
    symptomMatrixHistory: [matrixLogSchema],
    cbtQuestHistory: [questLogSchema],
    sosTriggerHistory: [sosLogSchema],
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

userSchema.virtual("fullName").get(function fullName() {
  return `${this.firstName} ${this.surname}`.trim();
});

userSchema.methods.setPassword = async function setPassword(password) {
  this.passwordHash = await bcrypt.hash(password, 12);
};

userSchema.methods.comparePassword = function comparePassword(password) {
  if (!this.passwordHash) {
    return false;
  }
  return bcrypt.compare(password, this.passwordHash);
};

userSchema.set("toJSON", {
  transform(doc, ret) {
    delete ret.passwordHash;
    return ret;
  },
});

userSchema.index({ createdAt: -1 });
userSchema.index({ "moodLog.date": -1 });
userSchema.index({ "phq9History.date": -1 });
userSchema.index({ "symptomMatrixHistory.date": -1 });
userSchema.index({ "cbtQuestHistory.date": -1 });
userSchema.index({ role: 1, assignedClinicianIds: 1, updatedAt: -1 });

module.exports = mongoose.model("User", userSchema);
