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

require('dotenv').config();

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
    message: 'AutoMate Backend is running'
  });
});

// Socket.io Connection Listener
const socketManager = require('./src/sockets/socketManager');
socketManager.init(io);

// ⚡ Schedule background task to auto-cancel stale rides older than 30 mins & cleanup data
cron.schedule('* * * * *', async () => {
  try {
    const result = await db.query(`
      UPDATE rides
      SET status = 'cancelled'
      WHERE status = 'active'
      AND created_at < NOW() - INTERVAL '30 minutes'
      RETURNING id;
    `);

    if (result.rowCount > 0) {
      const rideIds = result.rows.map(r => r.id);
      console.log(`[Cron] Auto-cancelled ${result.rowCount} stale rides:`, rideIds);

      // Auto-purge notifications and chat messages for cancelled rides
      await db.query(`DELETE FROM notifications WHERE ride_id = ANY($1::uuid[])`, [rideIds]);
      await db.query(`DELETE FROM messages WHERE ride_id = ANY($1::uuid[])`, [rideIds]);

      // Real-time broadcast to all connected mobile clients
      socketManager.getIO().emit('rideUpdated');
      socketManager.getIO().emit('newRide');
    }
  } catch (error) {
    console.error('[Cron] Error auto-cancelling rides:', error);
  }
});

// Start Server
const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});