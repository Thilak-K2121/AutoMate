const jwt = require('jsonwebtoken');
const { createAdapter } = require('@socket.io/redis-adapter');
const redis = require('../config/redis');
const db = require('../config/db');

let ioInstance;

/**
 * 🔐 Socket security model
 * ---------------------------------------------------------------------------
 * - Handshake: the app sends its JWT in `auth.token`. A valid token binds the
 *   socket to that user (socket.data.userId). An invalid/expired token is
 *   always rejected.
 * - Rooms:
 *     user_<id>        personal notifications — joined ONLY for the verified user
 *     ride_<id>        public ride status (ended / updated / removed) — anyone
 *                      viewing the ride page
 *     ride_chat_<id>   chat messages, typing, read ticks — ride MEMBERS only
 *
 * Enforcement: STRICT by default — token-less sockets are refused at the
 * handshake (all installed apps send the token). Emergency escape hatch only:
 * set SOCKET_AUTH_REQUIRED=false on Render to temporarily accept token-less
 * "legacy" sockets with the old behaviour.
 */

const JWT_SECRET = () => process.env.JWT_SECRET || 'fallback_super_secret_key';
const authRequired = () => process.env.SOCKET_AUTH_REQUIRED !== 'false';

const chatRoom = (rideId) => `ride_chat_${rideId}`;

// Is this user a participant (host is a participant too) of the ride?
const isRideMember = async (rideId, userId) => {
  try {
    const result = await db.query(
      'SELECT 1 FROM ride_participants WHERE ride_id = $1 AND user_id = $2 LIMIT 1',
      [rideId, userId]
    );
    return result.rowCount > 0;
  } catch (err) {
    return false; // e.g. malformed ride id
  }
};

const authenticateSocket = (socket, next) => {
  const raw = socket.handshake.auth && socket.handshake.auth.token;
  const token = typeof raw === 'string' ? raw.trim() : '';

  if (!token) {
    if (authRequired()) {
      return next(new Error('unauthorized: token required'));
    }
    socket.data.legacy = true; // escape hatch only (SOCKET_AUTH_REQUIRED=false)
    return next();
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET());
    socket.data.userId = String(payload.id);
    return next();
  } catch (err) {
    return next(new Error('unauthorized: invalid token'));
  }
};

const socketManager = {
  // Initialize socket listeners
  init: (io) => {
    ioInstance = io;

    // 🌐 Cross-instance fan-out: with the Redis adapter, io.emit() / io.to(room).emit()
    // are published to Redis and delivered by whichever instance holds the target sockets.
    // Without Redis, Socket.io keeps its default in-memory adapter (single instance).
    if (redis.isReady()) {
      const { pub, sub } = redis.getPubSub();
      io.adapter(createAdapter(pub, sub, { key: 'automate:socket.io' }));
      console.log('✅ Socket.io Redis adapter enabled (multi-instance ready)');
    } else {
      console.log('ℹ️ Socket.io using in-memory adapter (single-instance mode)');
    }

    // 🔐 Verify the JWT before any event handler runs
    io.use(authenticateSocket);
    console.log(
      `🔐 Socket auth: ${authRequired() ? 'REQUIRED' : 'LEGACY ALLOWED (SOCKET_AUTH_REQUIRED=false)'}`
    );

    io.on('connection', (socket) => {
      const userId = socket.data.userId; // undefined for legacy sockets
      console.log(
        `New client connected: ${socket.id} ${userId ? `(user ${userId})` : '(legacy, no token)'}`
      );

      // Personal notification room — bound to the verified user, not the client's claim
      socket.on('joinUserRoom', (claimedUserId) => {
        if (userId) {
          if (claimedUserId && String(claimedUserId) !== userId) {
            console.warn(`⚠️ Socket ${socket.id} asked for user_${claimedUserId} but is user ${userId}; ignored`);
          }
          socket.join(`user_${userId}`);
        } else {
          socket.join(`user_${claimedUserId}`); // legacy (escape hatch only)
        }
      });

      // Ride page: everyone gets public ride status; only members get the chat room
      socket.on('joinRideRoom', async (rideId, callback) => {
        const ack = typeof callback === 'function' ? callback : () => {};
        if (!rideId) return ack({ ok: false, error: 'rideId required' });

        socket.join(`ride_${rideId}`);

        if (!userId) {
          socket.join(chatRoom(rideId)); // legacy (escape hatch only)
          return ack({ ok: true, chat: true });
        }

        const member = await isRideMember(rideId, userId);
        if (member) socket.join(chatRoom(rideId));
        ack({ ok: true, chat: member });
      });

      socket.on('leaveRideRoom', (rideId) => {
        socket.leave(`ride_${rideId}`);
        socket.leave(chatRoom(rideId));
      });

      // Chat signals: only from sockets that are in the members-only chat room,
      // and the sender identity comes from the verified token when available.
      const inChat = (rideId) => rideId && socket.rooms.has(chatRoom(rideId));

      socket.on('typing', ({ rideId, userName, userId: claimed } = {}) => {
        if (!inChat(rideId)) return;
        socket.to(chatRoom(rideId)).emit('userTyping', {
          rideId,
          userName,
          userId: userId || claimed,
        });
      });

      socket.on('stopTyping', ({ rideId, userId: claimed } = {}) => {
        if (!inChat(rideId)) return;
        socket.to(chatRoom(rideId)).emit('userStoppedTyping', {
          rideId,
          userId: userId || claimed,
        });
      });

      // Real-time message read receipts (Double Blue Ticks)
      socket.on('markMessagesRead', ({ rideId, userId: claimed } = {}) => {
        if (!inChat(rideId)) return;
        socket.to(chatRoom(rideId)).emit('messagesRead', {
          rideId,
          readerId: userId || claimed,
        });
      });

      socket.on('disconnect', () => {
        console.log(`Client disconnected: ${socket.id}`);
      });
    });
  },

  // Room name helper for controllers
  chatRoom,

  /**
   * Immediately remove a user's sockets from a ride's chat room (on leave /
   * remove / block). Works across all instances via the Redis adapter.
   */
  removeUserFromRideChat: (userId, rideId) => {
    if (!ioInstance || !userId || !rideId) return;
    ioInstance.in(`user_${userId}`).socketsLeave(chatRoom(rideId));
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
