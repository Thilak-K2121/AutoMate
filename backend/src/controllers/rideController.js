const db = require('../config/db');
const socketManager = require('../sockets/socketManager');

const rideController = {

  // ✅ CREATE RIDE
  createRide: async (req, res) => {
    try {
      const { destination, meeting_point, seats_total, female_only } = req.body;
      const creator_id = req.user.id;

      const seats_available = seats_total - 1;

      // ✅ safer boolean parsing
      const isFemaleOnly =
          female_only === true ||
          female_only === 'true' ||
          female_only === 'on' ||
          female_only === 1;
      
      console.log({
  incoming_female_only: female_only,
  parsed: isFemaleOnly,
  type: typeof female_only
});

      await db.query('BEGIN');

      const rideResult = await db.query(
        `INSERT INTO rides 
         (destination, meeting_point, creator_id, seats_total, seats_available, female_only) 
         VALUES ($1, $2, $3, $4, $5, $6) 
         RETURNING *`,
        [destination, meeting_point, creator_id, seats_total, seats_available, isFemaleOnly]
      );

      const newRide = rideResult.rows[0];

      await db.query(
        `INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)`,
        [newRide.id, creator_id]
      );

      await db.query('COMMIT');

      res.status(201).json({
        message: 'Ride created successfully',
        ride: newRide
      });

    } catch (error) {
      await db.query('ROLLBACK');
      console.error(error);
      res.status(500).json({ message: 'Server error creating ride' });
    }
  },

  // ✅ GET NEARBY RIDES (FIXED 🔥)
  getNearbyRides: async (req, res) => {
    try {
      const currentUserId = req.user.id;

     const result = await db.query(
  `SELECT DISTINCT r.*, u.name as creator_name, u.rating 
   FROM rides r 
   JOIN users u ON r.creator_id = u.id 
   LEFT JOIN ride_participants rp 
     ON r.id = rp.ride_id AND rp.user_id = $1
   CROSS JOIN (
     SELECT COALESCE(LOWER(TRIM(gender)), '') as gender 
     FROM users WHERE id = $1
   ) as cu
   WHERE r.status IN ('active', 'full')
   AND (
     (
       r.status = 'active'
       AND r.seats_available > 0
       AND (
         r.female_only = false
         OR cu.gender = 'female'
       )
     )
     OR rp.user_id IS NOT NULL
   )
   ORDER BY r.created_at DESC`,
  [currentUserId]
);
      res.status(200).json({ rides: result.rows });

    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching nearby rides' });
    }
  },

  // ✅ JOIN RIDE
  joinRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      await db.query('BEGIN');

      const rideCheck = await db.query(
        'SELECT * FROM rides WHERE id = $1 FOR UPDATE',
        [rideId]
      );

      if (rideCheck.rows.length === 0) {
        await db.query('ROLLBACK');
        return res.status(404).json({ message: 'Ride not found' });
      }

      const ride = rideCheck.rows[0];

      // ✅ ADD HERE
      console.log({
        female_only: ride.female_only,
        type: typeof ride.female_only
      });

      const isRideFemaleOnly = ride.female_only === true;

      if (isRideFemaleOnly) {
        const userCheck = await db.query(
          'SELECT gender FROM users WHERE id = $1',
          [userId]
        );

        const userGender = (userCheck.rows[0]?.gender || '')
              .trim()
              .toLowerCase();

        if (userGender !== 'female') {
          await db.query('ROLLBACK');
          return res.status(403).json({
            message: 'Access Denied: Female-only ride.'
          });
        }
      }

      const participantCheck = await db.query(
        'SELECT 1 FROM ride_participants WHERE ride_id = $1 AND user_id = $2',
        [rideId, userId]
      );

      if (participantCheck.rows.length > 0) {
        await db.query('ROLLBACK');
        return res.status(400).json({
          message: 'You have already joined this ride.'
        });
      }

      if (ride.seats_available <= 0) {
        await db.query('ROLLBACK');
        return res.status(400).json({
          message: 'Ride is full.'
        });
      }

      await db.query(
        'INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)',
        [rideId, userId]
      );
      // 👇 NEW: CREATE THE NOTIFICATION FOR THE HOST
      // 1. Fetch the user who just joined to get their name
      const joiningUser = await db.query('SELECT name FROM users WHERE id = $1', [userId]);
      const passengerName = joiningUser.rows[0]?.name?.split(' ')[0] || 'Someone';

      // 2. Insert the notification for the Ride Creator
      // Inside joinRide...
      // 👇 FIXED: Now we save the ride_id ($2) into the database!
      await db.query(
        `INSERT INTO notifications (user_id, ride_id, title, message, icon_type) 
         VALUES ($1, $2, $3, $4, $5)`,
        [
          ride.creator_id, 
          rideId, // <-- Pass the ride ID here
          'New Passenger!', 
          `${req.user.name || 'Someone'} joined your ride to ${ride.destination}`, 
          'person'
        ]
      );
      // 👆 END NOTIFICATION LOGIC
      socketManager.getIO()
  .to(`user_${ride.creator_id}`)
  .emit('newNotification', {
    title: 'New Passenger! 🚗',
    message: `${passengerName} just joined your ride to ${ride.destination}.`,
    icon_type: 'person_add'
  });
      

      const newSeats = ride.seats_available - 1;
      const newStatus = newSeats === 0 ? 'full' : 'active';

      await db.query(
        'UPDATE rides SET seats_available = $1, status = $2 WHERE id = $3',
        [newSeats, newStatus, rideId]
      );

      await db.query('COMMIT');

      res.status(200).json({
        message: 'Successfully joined the ride!'
      });

    } catch (error) {
      await db.query('ROLLBACK');
      console.error(error);
      res.status(500).json({ message: 'Server error joining ride' });
    }
  },

  // ✅ LEAVE RIDE
  leaveRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      await db.query('BEGIN');

      const deleteResult = await db.query(
        'DELETE FROM ride_participants WHERE ride_id = $1 AND user_id = $2 RETURNING *',
        [rideId, userId]
      );

      if (deleteResult.rows.length === 0) {
        throw new Error('Not a participant');
      }

      await db.query(
        "UPDATE rides SET seats_available = seats_available + 1, status = 'active' WHERE id = $1",
        [rideId]
      );

      await db.query('COMMIT');

      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('rideLeft', {
          message: 'User left ride',
          userId
        });

      res.status(200).json({ message: 'Left ride successfully' });

    } catch (error) {
      await db.query('ROLLBACK');
      res.status(400).json({
        message: error.message || 'Error leaving ride'
      });
    }
  },

  // ✅ GET RIDE DETAILS
  getRideDetails: async (req, res) => {
    try {
      const { id } = req.params;

      const rideResult = await db.query(
        `SELECT r.*, u.name as creator_name, u.phone as creator_phone, u.rating 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         WHERE r.id = $1`,
        [id]
      );

      if (rideResult.rows.length === 0) {
        return res.status(404).json({ message: 'Ride not found' });
      }

      const participantsResult = await db.query(
        `SELECT u.id, u.name, u.rating, rp.joined_at 
         FROM ride_participants rp 
         JOIN users u ON rp.user_id = u.id 
         WHERE rp.ride_id = $1 
         ORDER BY rp.joined_at ASC`,
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

  // ✅ END RIDE
  endRide: async (req, res) => {
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      const result = await db.query(
        "UPDATE rides SET status = 'completed' WHERE id = $1 AND creator_id = $2 RETURNING *",
        [rideId, userId]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({
          message: 'Not authorized or ride not found'
        });
      }

      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('rideEnded', {
          message: 'Ride ended'
        });

     try {
        await db.query('DELETE FROM notifications WHERE ride_id = $1', [rideId]);
      } catch (err) {
        console.error('Failed to delete notifications:', err);
}

      res.status(200).json({
        message: 'Ride ended successfully'
      });

    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error ending ride' });
    }
  },

  // ✅ GET USER STATS (For the Profile Page)
  getUserStats: async (req, res) => {
    try {
      const userId = req.user.id;

      // Count rides the user created
      const hostedCount = await db.query(
        'SELECT COUNT(*) FROM rides WHERE creator_id = $1', 
        [userId]
      );

      // Count rides the user joined (where they are a participant, but NOT the creator)
      const joinedCount = await db.query(
        `SELECT COUNT(*) FROM ride_participants rp 
         JOIN rides r ON rp.ride_id = r.id 
         WHERE rp.user_id = $1 AND r.creator_id != $1`,
        [userId]
      );

      res.status(200).json({
        ridesHosted: parseInt(hostedCount.rows[0].count),
        ridesTaken: parseInt(joinedCount.rows[0].count)
      });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching user stats' });
    }
  },

  // ✅ GET MY RIDES HISTORY (For the Dashboard)
  getMyRides: async (req, res) => {
    try {
      const userId = req.user.id;

      // Get rides user created (Hosted)
      const hostedRides = await db.query(
        `SELECT r.*, u.name as creator_name 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         WHERE r.creator_id = $1 
         ORDER BY r.created_at DESC`, 
         [userId]
      );

      // Get rides user joined as passenger (Joined)
      const joinedRides = await db.query(
        `SELECT r.*, u.name as creator_name 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         JOIN ride_participants rp ON r.id = rp.ride_id 
         WHERE rp.user_id = $1 AND r.creator_id != $1 
         ORDER BY r.created_at DESC`, 
         [userId]
      );

      res.status(200).json({
        hosted: hostedRides.rows,
        joined: joinedRides.rows
      });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching my rides' });
    }
  }
};


module.exports = rideController;