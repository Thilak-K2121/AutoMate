const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const authRoutes = require('./src/routes/authRoutes');
const rideRoutes = require('./src/routes/rideRoutes'); // <-- NEW
const messageRoutes = require('./src/routes/messageRoutes'); // <-- NEW
require('dotenv').config();

// Initialize Express App
const app = express();
const server = http.createServer(app);

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
app.use('/api/messages', messageRoutes); // <-- NEW

// Basic Health Check Route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'AutoMate Backend is running' });
});

// Socket.io Connection Listener
// Initialize Socket.io Manager
const socketManager = require('./src/sockets/socketManager');
socketManager.init(io);

// Start Server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});