require('dotenv').config();

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const compression = require('compression');
const authRoutes = require('./src/routes/authRoutes');
const rideRoutes = require('./src/routes/rideRoutes');
const messageRoutes = require('./src/routes/messageRoutes');
const notificationRoutes = require('./src/routes/notificationRoutes');
const cron = require('node-cron');
const db = require('./src/config/db');
const redis = require('./src/config/redis');
const cache = require('./src/services/cacheService');
const socketManager = require('./src/sockets/socketManager');
const notificationService = require('./src/services/notificationService');

// Initialize Express App
const app = express();
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(compression()); // ⚡ 70-80% Gzip payload compression
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/messages', messageRoutes);

// Basic Health Check Route
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'AutoMate Backend is running',
    redis: redis.status(), // 'up' | 'down' | 'disabled'
    instance: redis.instanceId
  });
});

// 🔒 Distributed lock so a scheduled job runs on exactly ONE instance per tick.
// SET key value NX PX ttl → only the first instance to set the key wins.
// The lock is never released manually; it expires just before the next minute's tick.
// Without Redis (single instance) the job always runs.
const acquireCronLock = async (name, ttlMs) => {
  if (!redis.isReady()) return true;
  try {
    const result = await redis
      .getClient()
      .set(`automate:lock:cron:${name}`, redis.instanceId, 'PX', ttlMs, 'NX');
    return result === 'OK';
  } catch (err) {
    console.error(`[Cron] Lock error for ${name}:`, err.message);
    return false; // Redis is configured but failing: skip rather than risk duplicate runs
  }
};

// ⚡ Background task: auto-cancel stale rides older than 30 mins & cleanup data
const autoCancelStaleRides = async () => {
  if (!(await acquireCronLock('autocancel', 55000))) return;

  try {
    // 'full' rides are included too — previously they were never expired
    const result = await db.query(`
      UPDATE rides
      SET status = 'cancelled'
      WHERE status IN ('active', 'full')
      AND created_at < NOW() - INTERVAL '30 minutes'
      RETURNING id, destination;
    `);

    if (result.rowCount > 0) {
      const expiredRides = result.rows;
      const rideIds = expiredRides.map(r => r.id);
      console.log(`[Cron] (${redis.instanceId}) Auto-cancelled ${result.rowCount} stale rides:`, rideIds);

      // Everyone in each expired ride (host + passengers) — memberships are kept as history
      const membersRes = await db.query(
        'SELECT ride_id, user_id FROM ride_participants WHERE ride_id = ANY($1::uuid[])',
        [rideIds]
      );

      // Auto-purge notifications and chat messages for cancelled rides
      await db.query(`DELETE FROM notifications WHERE ride_id = ANY($1::uuid[])`, [rideIds]);
      await db.query(`DELETE FROM messages WHERE ride_id = ANY($1::uuid[])`, [rideIds]);

      // Drop cached ride lists so clients refetch fresh data
      await cache.clearAll();

      const io = socketManager.getIO();

      for (const ride of expiredRides) {
        // Tell anyone with the chat / ride details page open (same event as a manual cancel)
        io.to(`ride_${ride.id}`).emit('rideEnded', {
          message: 'This ride expired after 30 minutes and was cancelled.',
          rideId: ride.id,
          status: 'cancelled',
          reason: 'expired'
        });

        // 📲 Push notification to members whose app is in the background / closed
        const memberIds = membersRes.rows
          .filter(m => m.ride_id === ride.id)
          .map(m => m.user_id);

        if (memberIds.length > 0) {
          notificationService
            .sendToUsers(
              memberIds,
              'Ride Expired ⏰',
              `Your ride to ${ride.destination} expired after 30 minutes and was cancelled.`,
              { rideId: ride.id.toString(), type: 'RIDE_EXPIRED' }
            )
            .catch(err => console.error('[Cron] Expiry push error:', err.message));
        }
      }

      // Real-time broadcast to all connected mobile clients (all instances via Redis adapter)
      io.emit('rideUpdated');
      io.emit('newRide');
    }
  } catch (error) {
    console.error('[Cron] Error auto-cancelling rides:', error);
  }
};

const PORT = process.env.PORT || 3000;

const start = async () => {
  // 1. Connect Redis first (optional: falls back to single-instance mode)
  await redis.init();

  // 2. Socket.io listeners (+ Redis adapter when Redis is up)
  socketManager.init(io);

  // 3. Scheduled jobs
  cron.schedule('* * * * *', autoCancelStaleRides);

  // 4. Accept traffic
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT} (instance: ${redis.instanceId})`);
  });
};

// Graceful shutdown (Render sends SIGTERM on deploys / scale-downs)
const shutdown = (signal) => {
  console.log(`${signal} received → shutting down gracefully`);
  // io.close() disconnects all sockets and also closes the underlying HTTP server
  io.close(async () => {
    await redis.close();
    await db.pool.end().catch(() => {});
    process.exit(0);
  });
  // Force-exit if connections don't close in time
  setTimeout(() => process.exit(0), 10000).unref();
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start();
