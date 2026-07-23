const express = require("express");
const {
  createCarePlan,
  getClinicalAlerts,
  getHospitalDashboard,
  listCarePlans,
} = require("../controllers/clinicalController");
const { requireAuth } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(requireAuth);

router.get("/dashboard", getHospitalDashboard);
router.get("/alerts", getClinicalAlerts);
router.get("/care-plans", listCarePlans);
router.get("/care-plans/:userId", listCarePlans);
router.post("/care-plans", createCarePlan);

module.exports = router;
