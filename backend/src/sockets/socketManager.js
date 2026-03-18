let ioInstance;

const socketManager = {
  // Initialize socket listeners
  init: (io) => {
    ioInstance = io;
    
    io.on('connection', (socket) => {
      console.log(`New client connected: ${socket.id}`);

      // When a user opens a Ride Details page, they join that ride's real-time room
      socket.on('joinRideRoom', (rideId) => {
        socket.join(`ride_${rideId}`);
        console.log(`Socket ${socket.id} joined room: ride_${rideId}`);
      });

      // When a user leaves the page or the ride, they leave the room
      socket.on('leaveRideRoom', (rideId) => {
        socket.leave(`ride_${rideId}`);
        console.log(`Socket ${socket.id} left room: ride_${rideId}`);
      });

      socket.on('disconnect', () => {
        console.log(`Client disconnected: ${socket.id}`);
      });
    });
  },

  // Export a function to get the io instance from anywhere in our backend (like controllers)
  getIO: () => {
    if (!ioInstance) {
      throw new Error('Socket.io not initialized!');
    }
    return ioInstance;
  }
};

module.exports = socketManager;