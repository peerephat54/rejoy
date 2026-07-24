const User = require("../models/User");
const Report = require("../models/Report");

const USER_SUMMARY_FIELDS = [
  "firstName",
  "surname",
  "email",
  "age",
  "role",
  "allergies",
  "medicalHistory",
  "emergencyContactNumbers",
  "currentMedications",
  "symptomClusteringMatrix",
  "behavioralActivationTracking",
  "currentEnergyLevel",
  "dailyMoodCheckin",
  "selectedQuestsToday",
  "completedQuestsToday",
  "completedQuestsCount",
  "unlockedAnimals",
  "unlockedAnimalToday",
  "animalNicknames",
  "animalEncounterHistory",
  "positiveMemoryBank",
  "companionMirrorState",
  "currentIslandWeather",
  "authProvider",
  "onboardingComplete",
  "phq9Score",
  "createdAt",
  "updatedAt",
].join(" ");

const UPDATABLE_USER_FIELDS = new Set([
  "firstName",
  "surname",
  "age",
  "allergies",
  "medicalHistory",
  "emergencyContactNumbers",
  "currentMedications",
  "symptomClusteringMatrix",
  "behavioralActivationTracking",
  "currentEnergyLevel",
  "dailyMoodCheckin",
  "selectedQuestsToday",
  "completedQuestsToday",
  "unlockedAnimals",
  "animalNicknames",
  "positiveMemoryBank",
  "companionMirrorState",
  "currentIslandWeather",
  "onboardingComplete",
  "role",
]);

const SELF_SELECTABLE_ROLES = new Set(["patient", "doctor"]);

const DEFAULT_ANIMAL_POOL = [
  { id: "fox-01", family: "fox", name: "จิ้งจอกแสงอุ่น" },
  { id: "otter-02", family: "otter", name: "นากใจดี" },
  { id: "rabbit-03", family: "rabbit", name: "กระต่ายพักใจ" },
  { id: "owl-04", family: "owl", name: "นกฮูกเฝ้าใจ" },
  { id: "deer-05", family: "deer", name: "กวางเดินช้า" },
  { id: "seal-06", family: "seal", name: "แมวน้ำกอดคลื่น" },
  { id: "cat-07", family: "cat", name: "แมวเฝ้าสมุด" },
  { id: "lion-08", family: "lion", name: "สิงโตใจอ่อนโยน" },
  { id: "whale-09", family: "whale", name: "วาฬฟังเงียบ" },
  { id: "turtle-10", family: "turtle", name: "เต่าค่อยเป็นค่อยไป" },
  { id: "bear-11", family: "bear", name: "หมีผ้าห่ม" },
  { id: "panda-12", family: "panda", name: "แพนด้าหายใจลึก" },
];

function normalizeArray(value) {
  if (Array.isArray(value)) {
    return value.filter(Boolean);
  }

  if (value === undefined || value === null || value === "") {
    return [];
  }

  return [value].flat().filter(Boolean);
}

function lastItem(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return null;
  }

  return items[items.length - 1];
}

function normalizeString(value, fallback = "") {
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value).trim();
}

function normalizeBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes", "y"].includes(normalized)) return true;
    if (["false", "0", "no", "n"].includes(normalized)) return false;
  }
  return Boolean(value);
}

function pickSafeUserUpdates(body) {
  const updates = {};
  Object.entries(body || {}).forEach(([key, value]) => {
    if (UPDATABLE_USER_FIELDS.has(key)) {
      updates[key] = value;
    }
  });

  if (updates.role !== undefined) {
    const role = normalizeString(updates.role).toLowerCase();
    if (!SELF_SELECTABLE_ROLES.has(role)) {
      const error = new Error("Role must be patient or doctor");
      error.statusCode = 400;
      throw error;
    }
    updates.role = role;
    if (role === "doctor") {
      updates.onboardingComplete = true;
    }
  }

  return updates;
}

function animalFamily(animalId = "") {
  const normalized = normalizeString(animalId).toLowerCase();
  const knownAnimal = DEFAULT_ANIMAL_POOL.find(
    (animal) => normalized.includes(animal.family) || normalized === animal.id,
  );
  if (knownAnimal) return knownAnimal.family;
  return normalized.replace(/-\d+$/, "") || normalized;
}

function unlockedAnimalFamilies(unlockedAnimals = []) {
  return new Set(
    normalizeArray(unlockedAnimals).map((animal) => animalFamily(animal)),
  );
}

function deterministicIndex(seed, max) {
  if (max <= 0) return 0;
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return hash % max;
}

function chooseUnlockedAnimal(user, preferredAnimalId = "", seed = "") {
  const ownedFamilies = unlockedAnimalFamilies(user.unlockedAnimals);
  const preferred = normalizeString(preferredAnimalId);
  const preferredAnimal = DEFAULT_ANIMAL_POOL.find(
    (animal) =>
      preferred &&
      (preferred.includes(animal.family) || preferred === animal.id),
  );
  if (preferredAnimal && !ownedFamilies.has(preferredAnimal.family)) {
    return preferredAnimal;
  }

  const availableAnimals = DEFAULT_ANIMAL_POOL.filter(
    (animal) => !ownedFamilies.has(animal.family),
  );

  if (availableAnimals.length === 0) {
    return null;
  }

  const index = deterministicIndex(
    seed || `${user._id}:${user.completedQuestsCount}`,
    availableAnimals.length,
  );
  return availableAnimals[index];
}

function countUnlockedAnimals(totalCompletedQuests, currentUnlockedAnimals) {
  const currentCount = unlockedAnimalFamilies(currentUnlockedAnimals).size;
  const targetCount = Math.floor(totalCompletedQuests / 3);
  return Math.max(targetCount - currentCount, 0);
}

function latestMoodState(user) {
  const latestMood = lastItem(user.moodLog);
  const latestPhq9 = lastItem(user.phq9History);
  const moodLevel = Number(latestMood?.mood_level);
  const phq9Score = Number(latestPhq9?.total_score ?? user.phq9Score);

  if (phq9Score >= 20 || moodLevel <= 2) return "crisis";
  if (phq9Score >= 15 || moodLevel <= 4) return "heavy";
  if (phq9Score >= 10 || moodLevel <= 6) return "tired";
  if (phq9Score >= 5) return "calm";
  return "hopeful";
}

function companionMessage(animal, moodState, effortCount) {
  if (!animal) {
    return "วันนี้ไม่มีสัตว์ตัวใหม่ซ้ำเข้ามา แต่สัตว์บนเกาะเห็นความพยายามของคุณครบถ้วนแล้ว";
  }

  const supportByMood = {
    crisis:
      "มันจะนั่งอยู่ใกล้ ๆ แบบไม่เร่ง ไม่ถามซ้ำ และคอยพาคุณกลับมาหายใจทีละรอบ",
    heavy: "มันจะอยู่เป็นเพื่อนเงียบ ๆ ให้วันนี้ไม่ต้องผ่านคนเดียว",
    tired: "มันจะคอยเตือนว่าแค่ก้าวเล็ก ๆ วันนี้ก็นับว่าเก่งแล้ว",
    calm: "มันจะเดินเล่นบนเกาะและเก็บช่วงเวลาดี ๆ ไว้ให้คุณกลับมาดู",
    hopeful: "มันจะช่วยฉลองแบบนุ่ม ๆ เพราะความพยายามเล็ก ๆ ของคุณมีค่า",
  };

  return `${animal.name} อพยพมาอยู่บนเกาะจากความพยายาม ${effortCount} เควสของวันนี้ ${supportByMood[moodState] ?? supportByMood.calm}`;
}

async function createUser(req, res, next) {
  try {
    const payload = {
      ...req.body,
      allergies: normalizeArray(req.body.allergies),
      emergencyContactNumbers: normalizeArray(req.body.emergencyContactNumbers),
      currentMedications: normalizeArray(req.body.currentMedications),
      symptomClusteringMatrix: normalizeArray(req.body.symptomClusteringMatrix),
      selectedQuestsToday: normalizeArray(req.body.selectedQuestsToday),
      unlockedAnimals: normalizeArray(req.body.unlockedAnimals),
    };

    const user = await User.create(payload);
    return res.status(201).json(user);
  } catch (error) {
    return next(error);
  }
}

async function listUsers(req, res, next) {
  try {
    const limit = Math.min(Number(req.query.limit || 20), 100);
    const filter = req.user ? { _id: req.user._id } : {};
    const users = await User.find(filter)
      .select(USER_SUMMARY_FIELDS)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean({ virtuals: true });
    return res.json(users);
  } catch (error) {
    return next(error);
  }
}

async function getUserById(req, res, next) {
  try {
    const user = await User.findById(req.params.id).lean({ virtuals: true });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    return res.json(user);
  } catch (error) {
    return next(error);
  }
}

async function updateUser(req, res, next) {
  try {
    const updates = pickSafeUserUpdates(req.body);

    if (req.body.allergies !== undefined) {
      updates.allergies = normalizeArray(req.body.allergies);
    }
    if (req.body.emergencyContactNumbers !== undefined) {
      updates.emergencyContactNumbers = normalizeArray(
        req.body.emergencyContactNumbers,
      );
    }
    if (req.body.currentMedications !== undefined) {
      updates.currentMedications = normalizeArray(req.body.currentMedications);
    }
    if (req.body.symptomClusteringMatrix !== undefined) {
      updates.symptomClusteringMatrix = normalizeArray(
        req.body.symptomClusteringMatrix,
      );
    }
    if (req.body.selectedQuestsToday !== undefined) {
      updates.selectedQuestsToday = normalizeArray(
        req.body.selectedQuestsToday,
      );
    }
    if (req.body.unlockedAnimals !== undefined) {
      updates.unlockedAnimals = normalizeArray(req.body.unlockedAnimals);
    }

    const user = await User.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true,
    });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json(user);
  } catch (error) {
    return next(error);
  }
}

async function deleteUser(req, res, next) {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    return res.json({ message: "User deleted successfully" });
  } catch (error) {
    return next(error);
  }
}

async function getUserProfile(req, res, next) {
  try {
    const user = await User.findById(req.params.id).lean({ virtuals: true });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({
      user,
      summary: {
        fullName: `${user.firstName} ${user.surname}`.trim(),
        currentEnergyLevel: user.currentEnergyLevel,
        currentIslandWeather: user.currentIslandWeather,
        phq9Score: user.phq9Score,
        completedQuestsCount: user.completedQuestsCount,
        lastMoodCheckin: lastItem(user.moodLog),
        lastPhq9Log: lastItem(user.phq9History),
      },
    });
  } catch (error) {
    return next(error);
  }
}

async function getActiveClinicalProfile(req, res, next) {
  try {
    const limit = Math.min(Number(req.query.limit || 14), 30);
    const user = await User.findById(req.user._id)
      .select(USER_SUMMARY_FIELDS)
      .lean({ virtuals: true });

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const reports = await Report.find({ userId: user._id })
      .sort({ date: -1, createdAt: -1 })
      .limit(limit)
      .lean();

    return res.json({
      user,
      reports,
      meta: {
        reportLimit: limit,
        generatedAt: new Date().toISOString(),
      },
    });
  } catch (error) {
    return next(error);
  }
}

async function appendMoodLog(req, res, next) {
  try {
    const { mood_level, date } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    user.moodLog.push({
      mood_level,
      date: date ?? new Date(),
    });

    if (typeof mood_level === "number") {
      user.dailyMoodCheckin = String(mood_level);
    }

    await user.save();
    return res.status(201).json(lastItem(user.moodLog));
  } catch (error) {
    return next(error);
  }
}

async function appendPhq9Log(req, res, next) {
  try {
    const { total_score, date } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    user.phq9History.push({
      total_score,
      date: date ?? new Date(),
    });
    user.phq9Score = total_score;

    await user.save();
    return res.status(201).json(lastItem(user.phq9History));
  } catch (error) {
    return next(error);
  }
}

async function appendSymptomMatrixLog(req, res, next) {
  try {
    const {
      mood_score = 0,
      somatic_score = 0,
      behavioral_score = 0,
      date,
    } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    user.symptomMatrixHistory.push({
      mood_score,
      somatic_score,
      behavioral_score,
      date: date ?? new Date(),
    });
    user.symptomClusteringMatrix = [
      `mood:${mood_score}`,
      `somatic:${somatic_score}`,
      `behavioral:${behavioral_score}`,
    ];

    await user.save();
    return res.status(201).json(lastItem(user.symptomMatrixHistory));
  } catch (error) {
    return next(error);
  }
}

async function appendQuestLog(req, res, next) {
  try {
    const {
      energy_mode_selected = "rest",
      selected_quests = [],
      completed_quests = [],
      completion_rate = "0%",
      is_rest_day = false,
      date,
    } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const questList = normalizeArray(selected_quests);
    const completedList = normalizeArray(completed_quests);

    user.cbtQuestHistory.push({
      energy_mode_selected,
      selected_quests: questList,
      completed_quests: completedList,
      total_selected_quests: questList.length,
      completed_quests_count: completedList.length,
      completion_rate,
      is_rest_day,
      date: date ?? new Date(),
    });
    user.currentEnergyLevel = energy_mode_selected;
    user.selectedQuestsToday = questList;
    user.completedQuestsToday = completedList;
    user.completedQuestsCount += completedList.length;
    user.behavioralActivationTracking.questCompletionRate = completion_rate;

    await user.save();
    return res.status(201).json(lastItem(user.cbtQuestHistory));
  } catch (error) {
    return next(error);
  }
}

async function completeQuest(req, res, next) {
  try {
    const {
      quest_name,
      quest_animal_id,
      energy_mode_selected,
      completion_rate,
      is_rest_day,
      date,
    } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const questName = normalizeString(quest_name, "Quest");
    const questAnimalId = normalizeString(quest_animal_id);
    const nextCompletedCount = (user.completedQuestsCount ?? 0) + 1;
    const progressCount = nextCompletedCount % 3 || 3;
    const questList = [questName];
    const unlockAnimalNow = nextCompletedCount % 3 === 0;

    user.cbtQuestHistory.push({
      energy_mode_selected: normalizeString(
        energy_mode_selected,
        user.currentEnergyLevel ?? "rest",
      ),
      selected_quests: questList,
      completion_rate: normalizeString(completion_rate, `${progressCount}/3`),
      is_rest_day: normalizeBoolean(is_rest_day, false),
      date: date ?? new Date(),
    });
    user.currentEnergyLevel = normalizeString(
      energy_mode_selected,
      user.currentEnergyLevel ?? "rest",
    );
    user.selectedQuestsToday = questList;
    user.completedQuestsCount = nextCompletedCount;
    user.behavioralActivationTracking.questCompletionRate = normalizeString(
      completion_rate,
      `${progressCount}/3`,
    );

    let unlockedAnimal = null;
    if (unlockAnimalNow) {
      const encounterAnimal = chooseUnlockedAnimal(
        user,
        questAnimalId,
        `${user._id}:${nextCompletedCount}:${questName}`,
      );
      if (encounterAnimal) {
        unlockedAnimal = encounterAnimal.id;
        user.unlockedAnimals.push(unlockedAnimal);
        const moodState = latestMoodState(user);
        const message = companionMessage(encounterAnimal, moodState, 1);
        user.animalEncounterHistory.push({
          animalId: encounterAnimal.id,
          animalName: encounterAnimal.name,
          trigger: "quest_complete",
          effortCount: 1,
          moodState,
          message,
          date: date ?? new Date(),
        });
        user.companionMirrorState = {
          animalId: encounterAnimal.id,
          moodState,
          supportMessage: message,
          updatedAt: new Date(),
        };
      }
      user.currentIslandWeather = "sunny";
    }

    user.unlockedAnimalToday = unlockedAnimal ?? user.unlockedAnimalToday;

    await user.save();

    return res.status(201).json({
      message: unlockAnimalNow
        ? unlockedAnimal
          ? `มีเพื่อนใหม่มาอยู่บนเกาะ: ${unlockedAnimal}`
          : "ทำครบอีกก้าวแล้ว สัตว์บนเกาะเห็นความพยายามของคุณ"
        : "Quest completed.",
      user,
      unlockedAnimal,
      questsUntilNextAnimal: unlockAnimalNow ? 3 : 3 - progressCount,
      completedQuestsCount: user.completedQuestsCount,
      unlockedAnimals: user.unlockedAnimals,
    });
  } catch (error) {
    return next(error);
  }
}

async function finishQuestDay(req, res, next) {
  try {
    const {
      selected_quests = [],
      completed_quests = [],
      energy_mode_selected,
      completion_rate,
      is_rest_day = false,
      date,
    } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const selectedList = normalizeArray(selected_quests);
    const completedList = normalizeArray(completed_quests);
    const totalSelected = selectedList.length;
    const totalCompleted = completedList.length;

    const isRestDay = normalizeBoolean(is_rest_day, false);

    if (!isRestDay && totalCompleted < 3) {
      return res.status(400).json({
        message: "Need at least 3 completed quests to finish the day.",
        completed_quests_count: totalCompleted,
        total_selected_quests: totalSelected,
      });
    }

    const progressRate = isRestDay
      ? "Resting"
      : `${totalCompleted}/${totalSelected || totalCompleted}`;
    const questLogEntry = {
      energy_mode_selected: normalizeString(
        energy_mode_selected,
        user.currentEnergyLevel ?? "rest",
      ),
      selected_quests: selectedList,
      completed_quests: completedList,
      total_selected_quests: totalSelected,
      completed_quests_count: totalCompleted,
      completion_rate: normalizeString(completion_rate, progressRate),
      is_rest_day: isRestDay,
      date: date ?? new Date(),
    };

    user.cbtQuestHistory.push(questLogEntry);
    user.currentEnergyLevel = normalizeString(
      energy_mode_selected,
      user.currentEnergyLevel ?? "rest",
    );
    user.selectedQuestsToday = [];
    user.completedQuestsToday = [];
    user.behavioralActivationTracking.questCompletionRate = normalizeString(
      completion_rate,
      progressRate,
    );

    const totalAfterThisDay = user.completedQuestsCount + totalCompleted;
    const animalsToUnlock = countUnlockedAnimals(
      totalAfterThisDay,
      user.unlockedAnimals,
    );
    const unlockedAnimalsToday = [];
    const encountersToday = [];
    const moodState = latestMoodState(user);

    for (let i = 0; i < animalsToUnlock; i += 1) {
      const encounterAnimal = chooseUnlockedAnimal(
        user,
        "",
        `${user._id}:${totalAfterThisDay}:${i}:${selectedList.join("|")}`,
      );
      if (!encounterAnimal) {
        break;
      }
      user.unlockedAnimals.push(encounterAnimal.id);
      unlockedAnimalsToday.push(encounterAnimal.id);

      const message = companionMessage(
        encounterAnimal,
        moodState,
        totalCompleted,
      );
      const encounter = {
        animalId: encounterAnimal.id,
        animalName: encounterAnimal.name,
        trigger: "quest_day_finish",
        effortCount: totalCompleted,
        moodState,
        message,
        date: date ?? new Date(),
      };
      user.animalEncounterHistory.push(encounter);
      encountersToday.push(encounter);
    }

    user.completedQuestsCount = totalAfterThisDay;
    user.unlockedAnimalToday =
      unlockedAnimalsToday[unlockedAnimalsToday.length - 1] ?? "";
    user.currentIslandWeather = "sunny";
    const supportMessage =
      encountersToday[encountersToday.length - 1]?.message ??
      (isRestDay
        ? "วันนี้เป็นวันพักอย่างปลอดภัย สัตว์บนเกาะจะนอนพักอยู่ข้าง ๆ โดยไม่เร่งคุณ"
        : companionMessage(null, moodState, totalCompleted));
    user.companionMirrorState = {
      animalId:
        unlockedAnimalsToday[unlockedAnimalsToday.length - 1] ??
        user.unlockedAnimals[user.unlockedAnimals.length - 1] ??
        "",
      moodState,
      supportMessage,
      updatedAt: new Date(),
    };

    await user.save();

    return res.status(201).json({
      message: isRestDay
        ? "บันทึกวันพักอย่างปลอดภัยแล้ว สัตว์บนเกาะจะอยู่เป็นเพื่อนเงียบ ๆ"
        : unlockedAnimalsToday.length > 0
          ? encountersToday[encountersToday.length - 1].message
          : supportMessage,
      user,
      total_selected_quests: totalSelected,
      completed_quests_count: totalCompleted,
      completed_quests_rate: progressRate,
      unlocked_animals_today: unlockedAnimalsToday,
      animal_encounters_today: encountersToday,
      companion_message: supportMessage,
      questsUntilNextAnimal:
        totalAfterThisDay % 3 === 0 ? 3 : 3 - (totalAfterThisDay % 3),
    });
  } catch (error) {
    return next(error);
  }
}

async function appendSosLog(req, res, next) {
  try {
    const { trigger_source, notes = "", date } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    user.sosTriggerHistory.push({
      trigger_source,
      notes,
      date: date ?? new Date(),
    });

    await user.save();
    return res.status(201).json(lastItem(user.sosTriggerHistory));
  } catch (error) {
    return next(error);
  }
}

async function appendPositiveMemory(req, res, next) {
  try {
    const {
      prompt = "",
      answer = "",
      animal_id = "",
      mood_state = "",
      date,
    } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const trimmedAnswer = normalizeString(answer);
    if (!trimmedAnswer) {
      return res
        .status(400)
        .json({ message: "Positive memory answer is required." });
    }

    const latestAnimal =
      normalizeString(animal_id) ||
      user.unlockedAnimalToday ||
      user.unlockedAnimals[user.unlockedAnimals.length - 1] ||
      "";
    const moodState = normalizeString(mood_state, latestMoodState(user));

    user.positiveMemoryBank.push({
      prompt: normalizeString(prompt),
      answer: trimmedAnswer,
      animalId: latestAnimal,
      moodState,
      date: date ?? new Date(),
    });

    user.companionMirrorState = {
      animalId: latestAnimal,
      moodState,
      supportMessage:
        "เก็บความทรงจำเล็ก ๆ ไว้แล้ว ถ้าวันไหนใจหนัก ระบบจะหยิบกลับมาเตือนว่าคุณเคยผ่านวันนี้มาได้",
      updatedAt: new Date(),
    };

    await user.save();
    return res.status(201).json(lastItem(user.positiveMemoryBank));
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  appendMoodLog,
  appendPhq9Log,
  appendPositiveMemory,
  appendQuestLog,
  appendSosLog,
  appendSymptomMatrixLog,
  createUser,
  completeQuest,
  deleteUser,
  getUserById,
  getActiveClinicalProfile,
  getUserProfile,
  finishQuestDay,
  listUsers,
  updateUser,
};
