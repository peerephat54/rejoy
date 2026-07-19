const mongoose = require('mongoose');

const { Schema } = mongoose;

const questSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    energyLevel: {
      type: String,
      required: true,
      enum: ['rest', 'low', 'medium', 'high'],
    },
    reward: { type: String, default: '' },
    animalId: { type: String, default: '' },
    color: { type: String, default: '#5A8DEE' },
    isActive: { type: Boolean, default: true },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

questSchema.index({ energyLevel: 1, isActive: 1, createdAt: -1 });

module.exports = mongoose.model('Quest', questSchema);
