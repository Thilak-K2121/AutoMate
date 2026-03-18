const db = require('../config/db');
const socketManager = require('../sockets/socketManager'); // <-- NEW

const rideController = {
  // POST /api/rides/create
  createRide: async (req, res) => {
    try {
      const { destination, meeting_point, seats_total } = req.body;
      const creator_id = req.user.id; // From verifyToken middleware

      // A user creating a ride takes up 1 seat automatically
      const seats_available = seats_total - 1;

      // Start SQL Transaction
      await db.query('BEGIN');

      // 1. Insert the ride
      const rideResult = await db.query(
        `INSERT INTO rides (destination, meeting_point, creator_id, seats_total, seats_available) 
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [destination, meeting_point, creator_id, seats_total, seats_available]
      );
      const newRide = rideResult.rows[0];

      // 2. Add creator as a participant
      await db.query(
        `INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)`,
        [newRide.id, creator_id]
      );

      await db.query('COMMIT');
      res.status(201).json({ message: 'Ride created successfully', ride: newRide });
    } catch (error) {
      await db.query('ROLLBACK');
      console.error(error);
      res.status(500).json({ message: 'Server error creating ride' });
    }
  },

  // GET /api/rides/nearby
  getNearbyRides: async (req, res) => {
    try {
      // Fetch all active rides and join with the users table to get the creator's name
      const result = await db.query(
        `SELECT r.*, u.name as creator_name, u.rating 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         WHERE r.status = 'active' AND r.seats_available > 0
         ORDER BY r.created_at DESC`
      );
      res.status(200).json({ rides: result.rows });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching nearby rides' });
    }
  },

  // POST /api/rides/join
  joinRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      await db.query('BEGIN');

      // 1. Check if ride exists and has seats
      const rideCheck = await db.query('SELECT seats_available, status FROM rides WHERE id = $1 FOR UPDATE', [rideId]);
      if (rideCheck.rows.length === 0) throw new Error('Ride not found');
      if (rideCheck.rows[0].status !== 'active') throw new Error('Ride is no longer active');
      if (rideCheck.rows[0].seats_available <= 0) throw new Error('Ride is full');

      // 2. Check if user is already in this ride
      const participantCheck = await db.query('SELECT * FROM ride_participants WHERE ride_id = $1 AND user_id = $2', [rideId, userId]);
      if (participantCheck.rows.length > 0) throw new Error('You have already joined this ride');

      // 3. Add user to participants
      await db.query('INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)', [rideId, userId]);

      // 4. Update available seats
      const updateRide = await db.query(
        'UPDATE rides SET seats_available = seats_available - 1 WHERE id = $1 RETURNING *',
        [rideId]
      );

      // 5. If seats hit 0, mark as full
      if (updateRide.rows[0].seats_available === 0) {
        await db.query("UPDATE rides SET status = 'full' WHERE id = $1", [rideId]);
      }

      await db.query('COMMIT');
      socketManager.getIO().to(`ride_${rideId}`).emit('rideJoined', {
        message: 'A new user joined the ride!',
        userId: userId,
        seats_available: updateRide.rows[0].seats_available
      });
      res.status(200).json({ message: 'Joined ride successfully' });
    } catch (error) {
      await db.query('ROLLBACK');
      res.status(400).json({ message: error.message || 'Server error joining ride' });
    }
  },

  // POST /api/rides/leave
  leaveRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      await db.query('BEGIN');

      // 1. Remove user from participants
      const deleteResult = await db.query(
        'DELETE FROM ride_participants WHERE ride_id = $1 AND user_id = $2 RETURNING *',
        [rideId, userId]
      );
      if (deleteResult.rows.length === 0) throw new Error('You are not a participant in this ride');

      // 2. Add the seat back and ensure status is active
      await db.query(
        "UPDATE rides SET seats_available = seats_available + 1, status = 'active' WHERE id = $1",
        [rideId]
      );

      await db.query('COMMIT');
      socketManager.getIO().to(`ride_${rideId}`).emit('rideLeft', {
        message: 'A user left the ride.',
        userId: userId
      });
      res.status(200).json({ message: 'Left ride successfully' });
    } catch (error) {
      await db.query('ROLLBACK');
      res.status(400).json({ message: error.message || 'Server error leaving ride' });
    }
  },

  // GET /api/rides/:id
  getRideDetails: async (req, res) => {
    try {
      const { id } = req.params;

      // 1. Get ride info (NEW: Added u.phone as creator_phone)
      const rideResult = await db.query(
        `SELECT r.*, u.name as creator_name, u.phone as creator_phone, u.rating 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         WHERE r.id = $1`,
        [id]
      );
      if (rideResult.rows.length === 0) return res.status(404).json({ message: 'Ride not found' });

      // 2. Get all participants for this ride
      const participantsResult = await db.query(
        `SELECT u.id, u.name, u.rating, rp.joined_at 
         FROM ride_participants rp 
         JOIN users u ON rp.user_id = u.id 
         WHERE rp.ride_id = $1 ORDER BY rp.joined_at ASC`,
        [id]
      );

      res.status(200).json({
        ride: rideResult.rows[0],
        participants: participantsResult.rows
      });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching ride details' });
    }
  },
  // POST /api/rides/end
  endRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id; // The person requesting to end the ride

      // Update the ride status to 'completed' ONLY if the requester is the creator
      const result = await db.query(
        "UPDATE rides SET status = 'completed' WHERE id = $1 AND creator_id = $2 RETURNING *",
        [rideId, userId]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({ message: 'Not authorized to end this ride or ride not found' });
      }

      // Optional: Emit a socket event so passengers know the ride ended
      socketManager.getIO().to(`ride_${rideId}`).emit('rideEnded', {
        message: 'The host has ended this ride.',
      });

      res.status(200).json({ message: 'Ride ended successfully' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error ending ride' });
    }
  },
};

module.exports = rideController;