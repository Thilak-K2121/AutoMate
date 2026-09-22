const express = require('express');
const router = express.Router();
const rideController = require('../controllers/rideController');
const verifyToken = require('../middleware/authMiddleware');

// All ride routes are protected
router.use(verifyToken);

router.post('/create', rideController.createRide);
router.get('/dashboard', rideController.getDashboardData);
router.get('/stats', rideController.getUserStats);
router.get('/my-rides', rideController.getMyRides);
router.get('/nearby', rideController.getNearbyRides);
router.post('/join', rideController.joinRide);
router.post('/leave', rideController.leaveRide);
router.post('/end', rideController.endRide);
router.post('/cancel', rideController.cancelRide);
router.post('/:id/remove', rideController.removePassenger);
router.post('/:id/block', rideController.blockPassenger);
router.get('/history', rideController.getRideHistory);
router.get('/:id', rideController.getRideDetails);

module.exports = router;