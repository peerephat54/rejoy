const Report = require('../models/Report');
const User = require('../models/User');

function lastItem(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return null;
  }

  return items[items.length - 1];
}

function normalizeBoolean(value, fallback = false) {
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

function normalizeMatrix(value = {}) {
  return {
    mood_score: Number(value.mood_score ?? 0),
    somatic_score: Number(value.somatic_score ?? 0),
    behavioral_score: Number(value.behavioral_score ?? 0),
  };
}

function normalizeReportCreatePayload(body) {
  const startDate = body.startDate ? new Date(body.startDate) : undefined;
  const endDate = body.endDate ? new Date(body.endDate) : undefined;

  return {
    userId: body.userId,
    date: body.date ? new Date(body.date) : undefined,
    phq9Score: body.phq9Score !== undefined ? Number(body.phq9Score) : undefined,
    symptomMatrix: normalizeMatrix(body.symptomMatrix),
    dailyMood: body.dailyMood ?? '',
    diaryNote: body.diaryNote ?? '',
    cbtCompletionRate: body.cbtCompletionRate ?? '0%',
    unlockedAnimalToday: body.unlockedAnimalToday ?? '',
    isRestDay: normalizeBoolean(body.isRestDay, false),
    isSosTriggered: normalizeBoolean(body.isSosTriggered, false),
    periodDays: body.periodDays !== undefined ? Number(body.periodDays) : undefined,
    startDate,
    endDate,
  };
}

function normalizeReportUpdatePayload(body) {
  const updates = {};

  if (body.userId !== undefined) updates.userId = body.userId;
  if (body.date !== undefined) updates.date = new Date(body.date);
  if (body.phq9Score !== undefined) updates.phq9Score = Number(body.phq9Score);
  if (body.symptomMatrix !== undefined) updates.symptomMatrix = normalizeMatrix(body.symptomMatrix);
  if (body.dailyMood !== undefined) updates.dailyMood = body.dailyMood;
  if (body.diaryNote !== undefined) updates.diaryNote = body.diaryNote;
  if (body.cbtCompletionRate !== undefined) updates.cbtCompletionRate = body.cbtCompletionRate;
  if (body.unlockedAnimalToday !== undefined) updates.unlockedAnimalToday = body.unlockedAnimalToday;
  if (body.isRestDay !== undefined) updates.isRestDay = normalizeBoolean(body.isRestDay, false);
  if (body.isSosTriggered !== undefined) updates.isSosTriggered = normalizeBoolean(body.isSosTriggered, false);
  if (body.periodDays !== undefined) updates.periodDays = Number(body.periodDays);
  if (body.startDate !== undefined) updates.startDate = new Date(body.startDate);
  if (body.endDate !== undefined) updates.endDate = new Date(body.endDate);

  return updates;
}

function activeUserId(req) {
  return req.user?._id?.toString();
}

async function listReports(req, res, next) {
  try {
    const filter = {};
    const limit = Math.min(Number(req.query.limit || 50), 100);

    if (activeUserId(req)) {
      filter.userId = activeUserId(req);
    } else if (req.query.userId) {
      filter.userId = req.query.userId;
    }

    const reports = await Report.find(filter)
      .sort({ date: -1, createdAt: -1 })
      .limit(limit)
      .populate('userId', 'firstName surname age')
      .lean();
    return res.json(reports);
  } catch (error) {
    return next(error);
  }
}

async function listReportsByUser(req, res, next) {
  try {
    const limit = Math.min(Number(req.query.limit || 14), 100);
    const userId = activeUserId(req);
    if (userId && userId !== req.params.userId) {
      return res.status(403).json({ message: 'You can only access your own reports' });
    }
    const reports = await Report.find({ userId: userId ?? req.params.userId })
      .sort({ date: -1, createdAt: -1 })
      .limit(limit)
      .populate('userId', 'firstName surname age')
      .lean();
    return res.json(reports);
  } catch (error) {
    return next(error);
  }
}

async function getReportById(req, res, next) {
  try {
    const report = await Report.findById(req.params.id)
      .populate('userId', 'firstName surname age')
      .lean();
    if (!report) {
      return res.status(404).json({ message: 'Report not found' });
    }
    if (activeUserId(req) && report.userId?._id?.toString() !== activeUserId(req)) {
      return res.status(403).json({ message: 'You can only access your own report' });
    }
    return res.json(report);
  } catch (error) {
    return next(error);
  }
}

async function createReport(req, res, next) {
  try {
    const payload = normalizeReportCreatePayload(req.body);
    if (activeUserId(req)) {
      payload.userId = activeUserId(req);
    }
    const report = await Report.create(payload);
    return res.status(201).json(report);
  } catch (error) {
    return next(error);
  }
}

async function generateReportFromUser(req, res, next) {
  try {
    const userId = activeUserId(req);
    if (userId && userId !== req.params.userId) {
      return res.status(403).json({ message: 'You can only generate your own report' });
    }
    const user = await User.findById(userId ?? req.params.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const latestReport = await Report.findOne({ userId: user._id })
      .sort({ date: -1, createdAt: -1 })
      .lean();
    const lastMatrix = lastItem(user.symptomMatrixHistory) ?? {};
    const report = await Report.create({
      userId: user._id,
      date: new Date(),
      phq9Score: user.phq9Score,
      symptomMatrix: {
        mood_score: lastMatrix.mood_score ?? 0,
        somatic_score: lastMatrix.somatic_score ?? 0,
        behavioral_score: lastMatrix.behavioral_score ?? 0,
      },
      dailyMood: user.dailyMoodCheckin,
      diaryNote: latestReport?.diaryNote ?? '',
      cbtCompletionRate: latestReport?.cbtCompletionRate ?? user.behavioralActivationTracking?.questCompletionRate ?? '0%',
      unlockedAnimalToday: latestReport?.unlockedAnimalToday ?? lastItem(user.unlockedAnimals) ?? '',
      isRestDay: latestReport?.isRestDay ?? false,
      isSosTriggered: latestReport?.isSosTriggered ?? user.sosTriggerHistory.length > 0,
      periodDays: 14,
      startDate: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000),
      endDate: new Date(),
    });

    return res.status(201).json(report);
  } catch (error) {
    return next(error);
  }
}

async function updateReport(req, res, next) {
  try {
    const existing = await Report.findById(req.params.id).lean();
    if (!existing) {
      return res.status(404).json({ message: 'Report not found' });
    }
    if (activeUserId(req) && existing.userId.toString() !== activeUserId(req)) {
      return res.status(403).json({ message: 'You can only update your own report' });
    }

    const updates = normalizeReportUpdatePayload(req.body);
    if (activeUserId(req)) {
      delete updates.userId;
    }

    const report = await Report.findByIdAndUpdate(
      req.params.id,
      updates,
      {
        new: true,
        runValidators: true,
      },
    ).populate('userId', 'firstName surname age');

    if (!report) {
      return res.status(404).json({ message: 'Report not found' });
    }

    return res.json(report);
  } catch (error) {
    return next(error);
  }
}

async function deleteReport(req, res, next) {
  try {
    const existing = await Report.findById(req.params.id).lean();
    if (!existing) {
      return res.status(404).json({ message: 'Report not found' });
    }
    if (activeUserId(req) && existing.userId.toString() !== activeUserId(req)) {
      return res.status(403).json({ message: 'You can only delete your own report' });
    }

    await Report.findByIdAndDelete(req.params.id);

    return res.json({ message: 'Report deleted successfully' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  createReport,
  deleteReport,
  generateReportFromUser,
  getReportById,
  listReports,
  listReportsByUser,
  updateReport,
};
