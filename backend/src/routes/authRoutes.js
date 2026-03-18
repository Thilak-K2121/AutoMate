const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const verifyToken = require('../middleware/authMiddleware');

// Public routes for joining the app
router.post('/register', authController.register);
router.post('/login', authController.login);

// Protected route to get current user data
router.get('/me', verifyToken, authController.getMe);

module.exports = router;