const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const verifyToken = require('../middleware/authMiddleware');

router.use(verifyToken); // Protect these routes

router.get('/', notificationController.getUserNotifications);
router.put('/read', notificationController.markAsRead);

module.exports = router;