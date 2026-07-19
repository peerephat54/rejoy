const express = require("express");
const {
  createQuest,
  deleteQuest,
  getQuestById,
  listQuests,
  listQuestsByEnergyLevel,
  updateQuest,
} = require("../controllers/questController");
const { requireAuth } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/", listQuests);
router.get("/energy/:energyLevel", listQuestsByEnergyLevel);
router.post("/", requireAuth, createQuest);
router.get("/:id", getQuestById);
router.patch("/:id", requireAuth, updateQuest);
router.delete("/:id", requireAuth, deleteQuest);

module.exports = router;
