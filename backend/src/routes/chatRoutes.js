const express = require('express');
const { companionChat, dailyTopic } = require('../controllers/chatController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/companion', requireAuth, companionChat);
router.get('/daily-topic', requireAuth, dailyTopic);

module.exports = router;
