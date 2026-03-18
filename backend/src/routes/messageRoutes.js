const express = require('express');
const router = express.Router();
const messageController = require('../controllers/messageController');
const verifyToken = require('../middleware/authMiddleware');

// Protect all message routes
router.use(verifyToken);

router.get('/:rideId', messageController.getMessages);
router.post('/send', messageController.sendMessage);

module.exports = router;