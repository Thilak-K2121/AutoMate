const db = require('../config/db');
const socketManager = require('../sockets/socketManager');

const messageController = {
  // GET /api/messages/:rideId
  getMessages: async (req, res) => {
    try {
      const { rideId } = req.params;

      // Fetch all messages for this ride, joined with user data to get the sender's name
      const result = await db.query(
        `SELECT m.id, m.message, m.timestamp, m.sender_id, u.name as sender_name 
         FROM messages m 
         JOIN users u ON m.sender_id = u.id 
         WHERE m.ride_id = $1 
         ORDER BY m.timestamp ASC`,
        [rideId]
      );

      res.status(200).json({ messages: result.rows });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching messages.' });
    }
  },

  // POST /api/messages/send
  sendMessage: async (req, res) => {
    try {
      const { rideId, message } = req.body;
      const senderId = req.user.id; // From our verifyToken middleware

      if (!message || message.trim() === '') {
        return res.status(400).json({ message: 'Message cannot be empty.' });
      }

      // 1. (Optional but recommended security) Check if the user is actually in this ride
      const participantCheck = await db.query(
        'SELECT * FROM ride_participants WHERE ride_id = $1 AND user_id = $2',
        [rideId, senderId]
      );
      
      if (participantCheck.rows.length === 0) {
        return res.status(403).json({ message: 'You must join the ride to send messages.' });
      }

      // 2. Insert message into the database
      const msgResult = await db.query(
        `INSERT INTO messages (ride_id, sender_id, message) 
         VALUES ($1, $2, $3) RETURNING id, message, timestamp`,
        [rideId, senderId, message]
      );
      const newMessage = msgResult.rows[0];

      // 3. Fetch the sender's name so we can broadcast it clearly
      const userResult = await db.query('SELECT name FROM users WHERE id = $1', [senderId]);
      
      const fullMessagePayload = {
        id: newMessage.id,
        ride_id: rideId,
        sender_id: senderId,
        sender_name: userResult.rows[0].name,
        message: newMessage.message,
        timestamp: newMessage.timestamp
      };

      // 4. Emit the message in real-time to everyone in the ride's socket room
      socketManager.getIO().to(`ride_${rideId}`).emit('newMessage', fullMessagePayload);

      // 5. Return success response to the sender
      res.status(201).json({ message: 'Message sent', data: fullMessagePayload });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error sending message.' });
    }
  }
};

module.exports = messageController;