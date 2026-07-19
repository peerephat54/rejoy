const Quest = require('../models/Quest');

function normalizeString(value, fallback = '') {
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value).trim();
}

function normalizeBoolean(value, fallback = true) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].includes(normalized)) return true;
    if (['false', '0', 'no', 'n'].includes(normalized)) return false;
  }
  return Boolean(value);
}

function normalizeQuestCreatePayload(body) {
  return {
    name: normalizeString(body.name),
    description: normalizeString(body.description),
    energyLevel: normalizeString(body.energyLevel, 'rest'),
    reward: normalizeString(body.reward),
    animalId: normalizeString(body.animalId),
    color: normalizeString(body.color, '#5A8DEE'),
    isActive: normalizeBoolean(body.isActive, true),
  };
}

function normalizeQuestUpdatePayload(body) {
  const updates = {};

  if (body.name !== undefined) updates.name = normalizeString(body.name);
  if (body.description !== undefined) updates.description = normalizeString(body.description);
  if (body.energyLevel !== undefined) updates.energyLevel = normalizeString(body.energyLevel);
  if (body.reward !== undefined) updates.reward = normalizeString(body.reward);
  if (body.animalId !== undefined) updates.animalId = normalizeString(body.animalId);
  if (body.color !== undefined) updates.color = normalizeString(body.color);
  if (body.isActive !== undefined) updates.isActive = normalizeBoolean(body.isActive, true);

  return updates;
}

async function listQuests(req, res, next) {
  try {
    const filter = { isActive: true };

    if (req.query.energyLevel) {
      filter.energyLevel = req.query.energyLevel;
    }

    if (req.query.isActive !== undefined) {
      filter.isActive = normalizeBoolean(req.query.isActive, true);
    }

    const limit = Math.min(Number(req.query.limit || 50), 100);
    const quests = await Quest.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();
    return res.json(quests);
  } catch (error) {
    return next(error);
  }
}

async function getQuestById(req, res, next) {
  try {
    const quest = await Quest.findById(req.params.id).lean();
    if (!quest) {
      return res.status(404).json({ message: 'Quest not found' });
    }
    return res.json(quest);
  } catch (error) {
    return next(error);
  }
}

async function listQuestsByEnergyLevel(req, res, next) {
  try {
    const quests = await Quest.find({
      energyLevel: req.params.energyLevel,
      isActive: true,
    })
      .sort({ createdAt: -1 })
      .limit(Math.min(Number(req.query.limit || 50), 100))
      .lean();
    return res.json(quests);
  } catch (error) {
    return next(error);
  }
}

async function createQuest(req, res, next) {
  try {
    const quest = await Quest.create(normalizeQuestCreatePayload(req.body));
    return res.status(201).json(quest);
  } catch (error) {
    return next(error);
  }
}

async function updateQuest(req, res, next) {
  try {
    const quest = await Quest.findByIdAndUpdate(req.params.id, normalizeQuestUpdatePayload(req.body), {
      new: true,
      runValidators: true,
    });
    if (!quest) {
      return res.status(404).json({ message: 'Quest not found' });
    }
    return res.json(quest);
  } catch (error) {
    return next(error);
  }
}

async function deleteQuest(req, res, next) {
  try {
    const quest = await Quest.findByIdAndDelete(req.params.id);
    if (!quest) {
      return res.status(404).json({ message: 'Quest not found' });
    }
    return res.json({ message: 'Quest deleted successfully' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  createQuest,
  deleteQuest,
  getQuestById,
  listQuests,
  listQuestsByEnergyLevel,
  updateQuest,
};
