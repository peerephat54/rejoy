const express = require('express');
const { companionChat } = require('../controllers/chatController');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/companion', requireAuth, companionChat);

module.exports = router;
