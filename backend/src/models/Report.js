const mongoose = require('mongoose');

const { Schema } = mongoose;

const symptomMatrixSchema = new Schema(
  {
    mood_score: { type: Number, default: 0 },
    somatic_score: { type: Number, default: 0 },
    behavioral_score: { type: Number, default: 0 },
  },
  { _id: false },
);

const reportSchema = new Schema(
  {
    reportId: {
      type: String,
      unique: true,
      default: () => `REP-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    date: { type: Date, default: Date.now },
    phq9Score: { type: Number, default: 0, min: 0, max: 27 },
    symptomMatrix: { type: symptomMatrixSchema, default: () => ({}) },
    dailyMood: { type: String, default: '' },
    diaryNote: { type: String, default: '' },
    cbtCompletionRate: { type: String, default: '0%' },
    unlockedAnimalToday: { type: String, default: '' },
    isRestDay: { type: Boolean, default: false },
    isSosTriggered: { type: Boolean, default: false },
    periodDays: { type: Number, default: 14 },
    startDate: { type: Date },
    endDate: { type: Date },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

reportSchema.index({ userId: 1, date: -1 });
reportSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Report', reportSchema);
