const express = require("express");
const {
  appendMoodLog,
  appendPhq9Log,
  appendPositiveMemory,
  appendQuestLog,
  appendSosLog,
  appendSymptomMatrixLog,
  createUser,
  completeQuest,
  deleteUser,
  getActiveClinicalProfile,
  getUserById,
  getUserProfile,
  finishQuestDay,
  listUsers,
  updateUser,
} = require("../controllers/userController");
const { requireAuth, requireSelf } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(requireAuth);

router.get("/", listUsers);
router.post("/", (req, res) => {
  res
    .status(405)
    .json({ message: "Use /api/auth/register to create an account" });
});
router.get("/active/profile", getActiveClinicalProfile);
router.get("/:id", requireSelf, getUserById);
router.get("/:id/profile", requireSelf, getUserProfile);
router.patch("/:id", requireSelf, updateUser);
router.delete("/:id", requireSelf, deleteUser);

router.post("/:id/mood-log", requireSelf, appendMoodLog);
router.post("/:id/phq9-history", requireSelf, appendPhq9Log);
router.post("/:id/symptom-matrix-history", requireSelf, appendSymptomMatrixLog);
router.post("/:id/cbt-quest-history", requireSelf, appendQuestLog);
router.post("/:id/quest-complete", requireSelf, completeQuest);
router.post("/:id/quest-day/finish", requireSelf, finishQuestDay);
router.post("/:id/positive-memory", requireSelf, appendPositiveMemory);
router.post("/:id/sos-history", requireSelf, appendSosLog);

module.exports = router;
