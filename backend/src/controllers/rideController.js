const db = require('../config/db');
const socketManager = require('../sockets/socketManager');

// ⚡ Zero-cost in-memory cache with standard 10-second TTL
const cache = {
  data: new Map(),
  get(key) {
    const entry = this.data.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiry) {
      this.data.delete(key);
      return null;
    }
    return entry.value;
  },
  set(key, value, ttlMs = 10000) {
    this.data.set(key, { value, expiry: Date.now() + ttlMs });
  },
  clearPattern(prefix) {
    for (const key of this.data.keys()) {
      if (key.startsWith(prefix)) {
        this.data.delete(key);
      }
    }
  },
  clearAll() {
    this.data.clear();
  }
};

const rideController = {

  // ✅ CREATE RIDE (Optimized ACID Transactions & Atomic Set-based Cleanup)
  createRide: async (req, res) => {
    const client = await db.getClient();
    try {
      const { destination, meeting_point, seats_total, female_only, paymentMode } = req.body;
      const creator_id = req.user.id;
      const seats_available = seats_total - 1;

      const isFemaleOnly =
        female_only === true ||
        female_only === 'true' ||
        female_only === 'on' ||
        female_only === 1;

      await client.query('BEGIN');

      // Auto-cancel any previous active hosted ride
      await client.query(
        `UPDATE rides SET status = 'cancelled' WHERE creator_id = $1 AND status IN ('active', 'full')`,
        [creator_id]
      );

      // ⚡ Atomic Set-based query: Increment seats on previously joined active rides in 1 operation (Eliminates N+1 loop)
      await client.query(
        `UPDATE rides 
         SET seats_available = seats_available + 1, status = 'active'
         WHERE id IN (
           SELECT rp.ride_id FROM ride_participants rp
           JOIN rides r ON rp.ride_id = r.id
           WHERE rp.user_id = $1 AND r.status IN ('active', 'full')
         )`,
        [creator_id]
      );

      // Atomic delete all previous participant records
      await client.query(
        `DELETE FROM ride_participants WHERE user_id = $1`,
        [creator_id]
      );

      // Insert new hosted ride
      const rideResult = await client.query(
        `INSERT INTO rides 
        (destination, meeting_point, creator_id, seats_total, seats_available, female_only, payment_mode) 
        VALUES ($1, $2, $3, $4, $5, $6, $7) 
        RETURNING *`,
        [
          destination,
          meeting_point,
          creator_id,
          seats_total,
          seats_available,
          isFemaleOnly,
          paymentMode || 'Any'
        ]
      );

      const newRide = rideResult.rows[0];

      // Add creator as participant
      await client.query(
        `INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)`,
        [newRide.id, creator_id]
      );

      await client.query('COMMIT');

      // Invalidate read cache
      cache.clearAll();

      socketManager.getIO().emit('newRide');

      res.status(201).json({
        message: 'Ride created successfully',
        ride: newRide
      });

    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error creating ride:', error);
      res.status(500).json({ message: 'Server error creating ride' });
    } finally {
      client.release();
    }
  },

  // ✅ GET NEARBY RIDES (Cached + Optimized Query)
  getNearbyRides: async (req, res) => {
    try {
      const currentUserId = req.user.id;
      const cacheKey = `nearby_${currentUserId}`;
      const cached = cache.get(cacheKey);

      if (cached) {
        return res.status(200).json({ rides: cached });
      }

      const result = await db.query(
        `SELECT DISTINCT r.*, 
                u.name as creator_name, 
                u.gender as creator_gender, 
                u.phone as creator_phone, 
                u.rating 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         LEFT JOIN ride_participants rp 
           ON r.id = rp.ride_id AND rp.user_id = $1
         CROSS JOIN (
           SELECT COALESCE(LOWER(TRIM(gender)), '') as gender 
           FROM users WHERE id = $1
         ) as cu
         WHERE r.status IN ('active', 'full')
         AND r.id NOT IN (
           SELECT ride_id FROM blocked_passengers WHERE user_id = $1
         )
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

      cache.set(cacheKey, result.rows, 8000); // 8s TTL
      res.status(200).json({ rides: result.rows });

    } catch (error) {
      console.error('Error fetching nearby rides:', error);
      res.status(500).json({ message: 'Server error fetching nearby rides' });
    }
  },

  // ✅ CONSOLIDATED DASHBOARD ENDPOINT (BFF - Single Network Request for Flutter Dashboard)
  getDashboardData: async (req, res) => {
    try {
      const userId = req.user.id;
      const cacheKey = `dashboard_${userId}`;
      const cached = cache.get(cacheKey);

      if (cached) {
        return res.status(200).json(cached);
      }

      // Execute all 4 queries concurrently on database
      const [userRes, hostedRes, joinedRes, nearbyRes, notifRes] = await Promise.all([
        db.query('SELECT id, name, email, phone, rating, gender FROM users WHERE id = $1', [userId]),
        db.query(
          `SELECT r.*, u.name as creator_name 
           FROM rides r 
           JOIN users u ON r.creator_id = u.id 
           WHERE r.creator_id = $1 
           ORDER BY r.created_at DESC`,
          [userId]
        ),
        db.query(
          `SELECT r.*, u.name as creator_name 
           FROM rides r 
           JOIN users u ON r.creator_id = u.id 
           JOIN ride_participants rp ON r.id = rp.ride_id 
           WHERE rp.user_id = $1 AND r.creator_id != $1 
           ORDER BY r.created_at DESC`,
          [userId]
        ),
        db.query(
          `SELECT DISTINCT r.*, 
                  u.name as creator_name, 
                  u.gender as creator_gender, 
                  u.phone as creator_phone, 
                  u.rating 
           FROM rides r 
           JOIN users u ON r.creator_id = u.id 
           LEFT JOIN ride_participants rp 
             ON r.id = rp.ride_id AND rp.user_id = $1
           CROSS JOIN (
             SELECT COALESCE(LOWER(TRIM(gender)), '') as gender 
             FROM users WHERE id = $1
           ) as cu
           WHERE r.status IN ('active', 'full')
           AND r.id NOT IN (
             SELECT ride_id FROM blocked_passengers WHERE user_id = $1
           )
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
          [userId]
        ),
        db.query(
          'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20',
          [userId]
        )
      ]);

      const payload = {
        user: userRes.rows[0] || null,
        myRides: {
          hosted: hostedRes.rows,
          joined: joinedRes.rows
        },
        nearbyRides: nearbyRes.rows,
        notifications: notifRes.rows,
        hasUnreadNotifications: notifRes.rows.some(n => !n.is_read)
      };

      cache.set(cacheKey, payload, 6000); // 6s TTL
      res.status(200).json(payload);

    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      res.status(500).json({ message: 'Server error fetching dashboard data' });
    }
  },

  // ✅ JOIN RIDE (Strict Host Validation, Row-Level Locking & Atomic Updates)
  joinRide: async (req, res) => {
    const client = await db.getClient();
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      // 1. Block check
      const blockCheck = await client.query(
        'SELECT id FROM blocked_passengers WHERE ride_id = $1 AND user_id = $2',
        [rideId, userId]
      );
      if (blockCheck.rows.length > 0) {
        return res.status(403).json({ message: 'You are not permitted to join this ride.' });
      }

      await client.query('BEGIN');

      // 2. Lock the target ride row to prevent race conditions during seat booking
      const rideCheck = await client.query(
        'SELECT * FROM rides WHERE id = $1 FOR UPDATE',
        [rideId]
      );

      if (rideCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Ride not found' });
      }

      const ride = rideCheck.rows[0];

      // 🚫 Prevent joining own ride as passenger (Strict equality check)
      if (ride.creator_id === userId) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          message: 'You cannot join your own ride as a passenger.'
        });
      }

      // Check female-only constraint
      if (ride.female_only === true) {
        const userCheck = await client.query(
          'SELECT gender FROM users WHERE id = $1',
          [userId]
        );
        const userGender = (userCheck.rows[0]?.gender || '').trim().toLowerCase();
        if (userGender !== 'female') {
          await client.query('ROLLBACK');
          return res.status(403).json({
            message: 'Access Denied: Female-only ride.'
          });
        }
      }

      // 3. Auto-cancel any previous active hosted ride
      await client.query(
        `UPDATE rides SET status = 'cancelled' WHERE creator_id = $1 AND status IN ('active', 'full')`,
        [userId]
      );

      // 4. Check if already in this exact ride
      const alreadyIn = await client.query(
        'SELECT id FROM ride_participants WHERE ride_id = $1 AND user_id = $2',
        [rideId, userId]
      );
      if (alreadyIn.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'You have already joined this ride.' });
      }

      // 5. Atomic seat increment on previous active joined rides & participant delete
      await client.query(
        `UPDATE rides 
         SET seats_available = seats_available + 1, status = 'active'
         WHERE id IN (
           SELECT rp.ride_id FROM ride_participants rp
           JOIN rides r ON rp.ride_id = r.id
           WHERE rp.user_id = $1 AND r.status IN ('active', 'full')
         )`,
        [userId]
      );
      await client.query('DELETE FROM ride_participants WHERE user_id = $1', [userId]);

      // 6. Verify seat availability
      if (ride.seats_available <= 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Ride is full.' });
      }

      // 7. Add as participant
      await client.query(
        'INSERT INTO ride_participants (ride_id, user_id) VALUES ($1, $2)',
        [rideId, userId]
      );

      // 8. Notification to Host (ONLY if joining user is NOT the creator)
      if (userId !== ride.creator_id) {
        const joiningUser = await client.query(
          'SELECT name FROM users WHERE id = $1',
          [userId]
        );
        const passengerName = joiningUser.rows[0]?.name?.split(' ')[0] || 'Someone';

        await client.query(
          `INSERT INTO notifications (user_id, ride_id, title, message, icon_type) 
           VALUES ($1, $2, $3, $4, $5)`,
          [
            ride.creator_id,
            rideId,
            'New Passenger!',
            `${passengerName} joined your ride to ${ride.destination}`,
            'person'
          ]
        );

        socketManager.getIO()
          .to(`user_${ride.creator_id}`)
          .emit('newNotification', {
            title: 'New Passenger! 🚗',
            message: `${passengerName} just joined your ride to ${ride.destination}.`,
            icon_type: 'person_add'
          });
      }

      // 9. Update seat count and status
      const newSeats = ride.seats_available - 1;
      const newStatus = newSeats === 0 ? 'full' : 'active';

      await client.query(
        'UPDATE rides SET seats_available = $1, status = $2 WHERE id = $3',
        [newSeats, newStatus, rideId]
      );

      await client.query('COMMIT');

      // Invalidate cache
      cache.clearAll();

      socketManager.getIO().emit('newRide');
      socketManager.getIO().emit('rideUpdated', { rideId });

      res.status(200).json({
        message: 'Successfully joined the ride!'
      });

    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error joining ride:', error);
      res.status(500).json({ message: 'Server error joining ride' });
    } finally {
      client.release();
    }
  },

  // ✅ LEAVE RIDE (ACID Transactions & Invalidation)
  leaveRide: async (req, res) => {
    const client = await db.getClient();
    try {
      const { rideId } = req.body;
      const userId = req.user.id;

      await client.query('BEGIN');

      const deleteResult = await client.query(
        'DELETE FROM ride_participants WHERE ride_id = $1 AND user_id = $2 RETURNING *',
        [rideId, userId]
      );

      if (deleteResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: 'Not a participant in this ride.' });
      }

      await client.query(
        "UPDATE rides SET seats_available = seats_available + 1, status = 'active' WHERE id = $1",
        [rideId]
      );

      await client.query('COMMIT');

      // Invalidate cache
      cache.clearAll();

      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('rideLeft', {
          message: 'User left ride',
          userId,
          rideId
        });

      socketManager.getIO().emit('newRide');
      socketManager.getIO().emit('rideUpdated', { rideId });

      res.status(200).json({ message: 'Left ride successfully' });

    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error leaving ride:', error);
      res.status(500).json({ message: 'Error leaving ride' });
    } finally {
      client.release();
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
      console.error('Error fetching ride details:', error);
      res.status(500).json({ message: 'Server error fetching ride details' });
    }
  },

  // ✅ REMOVE PASSENGER
  removePassenger: async (req, res) => {
    const client = await db.getClient();
    try {
      const { id: rideId } = req.params;
      const { passengerId } = req.body;
      const hostId = req.user.id;

      const rideCheck = await client.query('SELECT creator_id FROM rides WHERE id = $1', [rideId]);
      if (rideCheck.rows.length === 0 || rideCheck.rows[0].creator_id !== hostId) {
        return res.status(403).json({ message: 'Only the host can remove passengers.' });
      }

      await client.query('BEGIN');
      const deleteRes = await client.query(
        'DELETE FROM ride_participants WHERE ride_id = $1 AND user_id = $2 RETURNING *',
        [rideId, passengerId]
      );

      if (deleteRes.rowCount > 0) {
        await client.query(
          "UPDATE rides SET seats_available = seats_available + 1, status = 'active' WHERE id = $1",
          [rideId]
        );
      }
      await client.query('COMMIT');

      // Invalidate cache
      cache.clearAll();

      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('passengerRemoved', { passengerId, rideId });
      socketManager.getIO().emit('newRide');
      socketManager.getIO().emit('rideUpdated', { rideId });

      res.status(200).json({ message: 'Passenger removed successfully.' });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error removing passenger:', error);
      res.status(500).json({ message: 'Error removing passenger' });
    } finally {
      client.release();
    }
  },

  // ✅ BLOCK PASSENGER
  blockPassenger: async (req, res) => {
    const client = await db.getClient();
    try {
      const { id: rideId } = req.params;
      const { passengerId } = req.body;
      const hostId = req.user.id;

      const rideCheck = await client.query('SELECT creator_id FROM rides WHERE id = $1', [rideId]);
      if (rideCheck.rows.length === 0 || rideCheck.rows[0].creator_id !== hostId) {
        return res.status(403).json({ message: 'Only the host can block passengers.' });
      }

      await client.query('BEGIN');
      
      await client.query(
        'INSERT INTO blocked_passengers (ride_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [rideId, passengerId]
      );

      const deleteRes = await client.query(
        'DELETE FROM ride_participants WHERE ride_id = $1 AND user_id = $2 RETURNING *',
        [rideId, passengerId]
      );

      if (deleteRes.rowCount > 0) {
        await client.query(
          "UPDATE rides SET seats_available = seats_available + 1, status = 'active' WHERE id = $1",
          [rideId]
        );
      }
      
      await client.query('COMMIT');

      // Invalidate cache
      cache.clearAll();

      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('passengerBlocked', { passengerId, rideId });
      socketManager.getIO().emit('newRide');
      socketManager.getIO().emit('rideUpdated', { rideId });

      res.status(200).json({ message: 'Passenger blocked successfully.' });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error blocking passenger:', error);
      res.status(500).json({ message: 'Error blocking passenger' });
    } finally {
      client.release();
    }
  },

  // ✅ END RIDE (Cascading Cleanup of Notifications and Messages)
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

      // Broadcast real-time ride ended to room & globally
      socketManager.getIO()
        .to(`ride_${rideId}`)
        .emit('rideEnded', {
          message: 'The host has ended this ride.',
          rideId
        });

      socketManager.getIO().emit('newRide');
      socketManager.getIO().emit('rideUpdated', { rideId, status: 'completed' });

      // ⚡ Auto-Purge notifications and messages for this ended ride
      try {
        await db.query('DELETE FROM notifications WHERE ride_id = $1', [rideId]);
        await db.query('DELETE FROM messages WHERE ride_id = $1', [rideId]);
      } catch (err) {
        console.error('Failed to cleanup completed ride data:', err);
      }

      // Invalidate cache
      cache.clearAll();

      res.status(200).json({
        message: 'Ride ended successfully'
      });

    } catch (error) {
      console.error('Error ending ride:', error);
      res.status(500).json({ message: 'Server error ending ride' });
    }
  },

  // ✅ GET USER STATS
  getUserStats: async (req, res) => {
    try {
      const userId = req.user.id;

      const hostedCount = await db.query(
        'SELECT COUNT(*) FROM rides WHERE creator_id = $1', 
        [userId]
      );

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
      console.error('Error fetching user stats:', error);
      res.status(500).json({ message: 'Server error fetching user stats' });
    }
  },

  // ✅ GET MY RIDES HISTORY
  getMyRides: async (req, res) => {
    try {
      const userId = req.user.id;

      const hostedRides = await db.query(
        `SELECT r.*, u.name as creator_name 
         FROM rides r 
         JOIN users u ON r.creator_id = u.id 
         WHERE r.creator_id = $1 
         ORDER BY r.created_at DESC`, 
        [userId]
      );

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
      console.error('Error fetching my rides:', error);
      res.status(500).json({ message: 'Server error fetching my rides' });
    }
  },

  // ✅ GET COMPLETED RIDE HISTORY
  getRideHistory: async (req, res) => {
    try {
      const userId = req.user.id;

      const result = await db.query(
        `SELECT r.*, u.name as creator_name
         FROM rides r
         JOIN users u ON r.creator_id = u.id
         LEFT JOIN ride_participants rp ON r.id = rp.ride_id
         WHERE (r.creator_id = $1 OR rp.user_id = $1)
         AND r.status = 'completed'
         ORDER BY r.created_at DESC`,
        [userId]
      );

      res.status(200).json({
        history: result.rows
      });

    } catch (error) {
      console.error('Error fetching history:', error);
      res.status(500).json({ message: 'Server error fetching history' });
    }
  }
};

module.exports = rideController;