const User = require("../models/User");
const Report = require("../models/Report");

const CLINICAL_USER_FIELDS = [
  "firstName",
  "surname",
  "email",
  "age",
  "role",
  "phq9Score",
  "dailyMoodCheckin",
  "completedQuestsCount",
  "behavioralActivationTracking",
  "sosTriggerHistory",
  "phq9History",
  "moodLog",
  "cbtQuestHistory",
  "carePlans",
  "assignedClinicianIds",
  "createdAt",
  "updatedAt",
].join(" ");

function isClinician(user) {
  return ["doctor", "psychologist", "admin"].includes(user?.role);
}

function isAdmin(user) {
  return user?.role === "admin";
}

function idEquals(left, right) {
  return left?.toString() === right?.toString();
}

function isAssignedClinician(patient, clinician) {
  return (patient.assignedClinicianIds || []).some((clinicianId) =>
    idEquals(clinicianId, clinician?._id),
  );
}

function canAccessCareSubject(requester, targetUser) {
  if (!requester || !targetUser) return false;
  if (idEquals(requester._id, targetUser._id)) return true;
  if (isAdmin(requester)) return true;
  return (
    isClinician(requester) &&
    targetUser.role === "patient" &&
    isAssignedClinician(targetUser, requester)
  );
}

function lastItem(items) {
  if (!Array.isArray(items) || items.length === 0) return null;
  return items[items.length - 1];
}

function daysAgo(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

function parseCbtRate(value = "") {
  const normalized = String(value || "").trim();
  if (!normalized || normalized.toLowerCase() === "resting") return 0;
  if (normalized.includes("/")) {
    const [doneRaw, totalRaw] = normalized.split("/");
    const done = Number(doneRaw);
    const total = Number(totalRaw);
    if (!Number.isFinite(done) || !Number.isFinite(total) || total <= 0) return 0;
    return Math.max(0, Math.min(100, (done / total) * 100));
  }
  const percent = Number(normalized.replace("%", ""));
  return Number.isFinite(percent) ? Math.max(0, Math.min(100, percent)) : 0;
}

function patientCode(user) {
  return `RJ-${user._id.toString().slice(-6).toUpperCase()}`;
}

function initials(user) {
  return `${user.firstName?.[0] ?? "P"}${user.surname?.[0] ?? ""}`.toUpperCase();
}

function displayName(user) {
  const fullName = [user.firstName, user.surname].filter(Boolean).join(" ").trim();
  return fullName || patientCode(user);
}

function average(items) {
  if (!items.length) return 0;
  return items.reduce((sum, value) => sum + value, 0) / items.length;
}

function getRecentReports(reports, userId) {
  return reports.filter((report) => report.userId.toString() === userId.toString());
}

function summarizePatient(user, reportsForUser) {
  const latestReport = reportsForUser[0] ?? null;
  const recentPhq = reportsForUser.map((report) => Number(report.phq9Score || 0));
  const recentCbt = reportsForUser.map((report) => parseCbtRate(report.cbtCompletionRate));
  const latestPhq = Number(latestReport?.phq9Score ?? lastItem(user.phq9History)?.total_score ?? user.phq9Score ?? 0);
  const latestMood = latestReport?.dailyMood || user.dailyMoodCheckin || "unknown";
  const recentSosCount = (user.sosTriggerHistory || []).filter(
    (entry) => new Date(entry.date) >= daysAgo(14),
  ).length + reportsForUser.filter((report) => report.isSosTriggered).length;
  const activeCarePlans = (user.carePlans || []).filter((plan) => plan.status === "active");
  const averageCbt = average(recentCbt);
  const riskStatus = calculateRiskStatus({ latestPhq, recentSosCount, averageCbt });

  return {
    userId: user._id,
    patientCode: patientCode(user),
    displayName: displayName(user),
    initials: initials(user),
    age: user.age,
    riskStatus,
    latestPhq9: latestPhq,
    latestMood,
    averagePhq9: Number(average(recentPhq).toFixed(1)),
    cbtCompletionAverage: Number(averageCbt.toFixed(1)),
    sosFlags14d: recentSosCount,
    activeCarePlanCount: activeCarePlans.length,
    lastReportAt: latestReport?.date ?? null,
    updatedAt: user.updatedAt,
  };
}

function calculateRiskStatus({ latestPhq, recentSosCount, averageCbt }) {
  if (recentSosCount > 0 || latestPhq >= 20) return "Urgent";
  if (latestPhq >= 15 || averageCbt < 30) return "Watch";
  return "Stable";
}

function buildAlerts(patientSummary, user) {
  const alerts = [];
  const latestSos = lastItem(user.sosTriggerHistory || []);
  const latestQuestLog = lastItem(user.cbtQuestHistory || []);
  const latestQuestDate = latestQuestLog?.date ? new Date(latestQuestLog.date) : null;

  if (patientSummary.latestPhq9 >= 20) {
    alerts.push({
      severity: "red",
      type: "PHQ9_HIGH",
      patientCode: patientSummary.patientCode,
      title: "PHQ-9 score is in severe range",
      message: `Latest PHQ-9 = ${patientSummary.latestPhq9}. Recommend same-day clinician review.`,
      createdAt: new Date().toISOString(),
    });
  } else if (patientSummary.latestPhq9 >= 15) {
    alerts.push({
      severity: "orange",
      type: "PHQ9_WATCH",
      patientCode: patientSummary.patientCode,
      title: "PHQ-9 score needs follow-up",
      message: `Latest PHQ-9 = ${patientSummary.latestPhq9}. Review trend before next appointment.`,
      createdAt: new Date().toISOString(),
    });
  }

  if (latestSos && new Date(latestSos.date) >= daysAgo(14)) {
    alerts.push({
      severity: "red",
      type: "SOS_TRIGGERED",
      patientCode: patientSummary.patientCode,
      title: "SOS used recently",
      message: `SOS source: ${latestSos.trigger_source}. This is a triage signal, not a 24/7 emergency dispatch.`,
      createdAt: latestSos.date,
    });
  }

  if (!latestQuestDate || latestQuestDate < daysAgo(5)) {
    alerts.push({
      severity: "yellow",
      type: "LOW_ACTIVITY",
      patientCode: patientSummary.patientCode,
      title: "No recent CBT quest activity",
      message: "Consider sending a low-energy care plan to reduce guilt and restart small wins.",
      createdAt: new Date().toISOString(),
    });
  }

  return alerts;
}

async function scopedUsers(req) {
  if (isAdmin(req.user)) {
    return User.find({ role: "patient" })
      .select(CLINICAL_USER_FIELDS)
      .sort({ updatedAt: -1 })
      .limit(100)
      .lean();
  }

  if (isClinician(req.user)) {
    return User.find({
      role: "patient",
      assignedClinicianIds: req.user._id,
    })
      .select(CLINICAL_USER_FIELDS)
      .sort({ updatedAt: -1 })
      .limit(100)
      .lean();
  }

  return User.find({ _id: req.user._id })
    .select(CLINICAL_USER_FIELDS)
    .lean();
}

async function getHospitalDashboard(req, res, next) {
  try {
    const users = await scopedUsers(req);
    const userIds = users.map((user) => user._id);
    const reports = await Report.find({
      userId: { $in: userIds },
      date: { $gte: daysAgo(14) },
    })
      .sort({ date: -1, createdAt: -1 })
      .lean();

    const patients = users.map((user) =>
      summarizePatient(user, getRecentReports(reports, user._id)),
    );
    const alerts = users.flatMap((user) => {
      const summary = patients.find(
        (patient) => patient.userId.toString() === user._id.toString(),
      );
      return summary ? buildAlerts(summary, user) : [];
    });

    return res.json({
      generatedAt: new Date().toISOString(),
      scope: isClinician(req.user) ? "hospital" : "self-demo",
      totals: {
        patients: patients.length,
        stable: patients.filter((patient) => patient.riskStatus === "Stable").length,
        watch: patients.filter((patient) => patient.riskStatus === "Watch").length,
        urgent: patients.filter((patient) => patient.riskStatus === "Urgent").length,
        alerts: alerts.length,
      },
      patients,
      alerts: alerts.slice(0, 20),
      privacy: {
        diaryTextHidden: true,
        deidentifiedPatientCodes: true,
        note: "Dashboard intentionally shows summary signals only. Raw diary text stays out of triage views.",
      },
    });
  } catch (error) {
    return next(error);
  }
}

async function getClinicalAlerts(req, res, next) {
  try {
    const users = await scopedUsers(req);
    const userIds = users.map((user) => user._id);
    const reports = await Report.find({
      userId: { $in: userIds },
      date: { $gte: daysAgo(14) },
    })
      .sort({ date: -1, createdAt: -1 })
      .lean();

    const alerts = users.flatMap((user) => {
      const summary = summarizePatient(user, getRecentReports(reports, user._id));
      return buildAlerts(summary, user);
    });

    const severityRank = { red: 0, orange: 1, yellow: 2 };
    alerts.sort((a, b) => severityRank[a.severity] - severityRank[b.severity]);
    return res.json({ generatedAt: new Date().toISOString(), alerts });
  } catch (error) {
    return next(error);
  }
}

async function listCarePlans(req, res, next) {
  try {
    const targetUserId = req.params.userId || req.user._id;
    const user = await User.findById(targetUserId)
      .select("role assignedClinicianIds carePlans")
      .lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!canAccessCareSubject(req.user, user)) {
      return res
        .status(403)
        .json({ message: "You can only access assigned care plans" });
    }
    return res.json({ carePlans: user.carePlans || [] });
  } catch (error) {
    return next(error);
  }
}

async function createCarePlan(req, res, next) {
  try {
    const targetUserId = req.body.userId || req.user._id;

    const title = String(req.body.title || "").trim();
    if (!title) {
      return res.status(400).json({ message: "Care plan title is required" });
    }

    const carePlan = {
      title,
      focusArea: req.body.focusArea || "general",
      note: req.body.note || "",
      recommendedQuestEnergy: req.body.recommendedQuestEnergy || "low",
      assignedBy: req.user._id,
      status: req.body.status || "active",
      createdAt: new Date(),
    };

    const user = await User.findById(targetUserId).select(
      "role assignedClinicianIds carePlans",
    );
    if (!user) return res.status(404).json({ message: "User not found" });
    if (!canAccessCareSubject(req.user, user)) {
      return res
        .status(403)
        .json({ message: "Only assigned clinicians can assign this care plan" });
    }

    user.carePlans.push(carePlan);
    await user.save();

    return res.status(201).json({
      message: "Care plan assigned",
      carePlan: user.carePlans[user.carePlans.length - 1],
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  createCarePlan,
  getClinicalAlerts,
  getHospitalDashboard,
  listCarePlans,
};
