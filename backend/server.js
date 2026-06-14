const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
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

// Routes
app.use('/api/notifications', notificationRoutes);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: '*', // For development; we can restrict this later
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/messages', messageRoutes);

// Basic Health Check Route
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'AutoMate Backend is running'
  });
});

// Socket.io Connection Listener
// Initialize Socket.io Manager
const socketManager = require('./src/sockets/socketManager');
socketManager.init(io);

// Schedule the task to run every minute
cron.schedule('* * * * *', async () => {
  try {
    // Find rides older than 30 minutes that are still active
    // and mark them as cancelled
    const result = await db.query(`
      UPDATE rides
      SET status = 'cancelled'
      WHERE status = 'active'
      AND created_at < NOW() - INTERVAL '30 minutes'
      RETURNING id;
    `);

    if (result.rowCount > 0) {
      console.log(
        `[Cron] Auto-cancelled ${result.rowCount} stale rides.`
      );
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