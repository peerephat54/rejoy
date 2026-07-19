const express = require("express");
const { getDeepHealth, getHealth } = require("../controllers/healthController");

const router = express.Router();

function requireDeepHealthAccess(req, res, next) {
  if (process.env.NODE_ENV !== "production") {
    return next();
  }

  const expectedKey = process.env.HEALTH_CHECK_KEY;
  const providedKey = req.get("x-health-check-key");
  if (expectedKey && providedKey === expectedKey) {
    return next();
  }

  return res.status(404).json({ message: "Not found" });
}

router.get("/", getHealth);
router.get("/deep", requireDeepHealthAccess, getDeepHealth);

module.exports = router;
