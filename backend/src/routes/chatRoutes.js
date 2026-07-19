const express = require('express');
const { companionChat } = require('../controllers/chatController');

const router = express.Router();

router.post('/companion', companionChat);

module.exports = router;
