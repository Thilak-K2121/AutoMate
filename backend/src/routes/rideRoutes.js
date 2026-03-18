const express = require('express');
const router = express.Router();
const rideController = require('../controllers/rideController');
const verifyToken = require('../middleware/authMiddleware');

// All ride routes are protected
router.use(verifyToken);

router.post('/create', rideController.createRide);
router.get('/nearby', rideController.getNearbyRides);
router.post('/join', rideController.joinRide);
router.post('/leave', rideController.leaveRide);
router.get('/:id', rideController.getRideDetails);

module.exports = router;