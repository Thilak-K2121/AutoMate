const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const db = require('../config/db');

let isInitialized = false;

try {
  const serviceAccountPath = path.join(__dirname, '../config/serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    isInitialized = true;
    console.log('✅ Firebase Admin SDK initialized successfully for FCM.');
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    isInitialized = true;
    console.log('✅ Firebase Admin SDK initialized via environment variable.');
  } else {
    console.warn('⚠️ Firebase serviceAccountKey.json not found. Push notifications will be skipped.');
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
}

const notificationService = {
  // 📱 Save or refresh device FCM token
  saveToken: async (userId, fcmToken, deviceType = 'android') => {
    if (!userId || !fcmToken) return;
    try {
      await db.query(
        `INSERT INTO user_devices (user_id, fcm_token, device_type, updated_at) 
         VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
         ON CONFLICT (user_id, fcm_token) 
         DO UPDATE SET updated_at = CURRENT_TIMESTAMP`,
        [userId, fcmToken, deviceType]
      );
    } catch (err) {
      console.error('Error saving FCM device token:', err.message);
    }
  },

  // 🚀 Send Push to a single user
  sendToUser: async (userId, title, body, data = {}) => {
    if (!isInitialized) {
      console.warn('⚠️ Push notification skipped: Firebase Admin SDK is not initialized on this server.');
      return;
    }
    if (!userId) return;

    try {
      const result = await db.query(
        'SELECT fcm_token FROM user_devices WHERE user_id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        console.log(`ℹ️ No registered FCM devices found for user ${userId}. Push skipped.`);
        return;
      }

      const tokens = result.rows.map(r => r.fcm_token);
      console.log(`🔔 Sending push notification to user ${userId} (${tokens.length} device tokens)...`);

      const messagePayload = {
        notification: {
          title,
          body
        },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'automate_rides_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        tokens
      };

      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      console.log(`✅ Push sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);
      
      // Clean up dead/invalid tokens
      if (response.failureCount > 0) {
        response.responses.forEach(async (resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === 'messaging/invalid-registration-token' ||
              errCode === 'messaging/registration-token-not-registered'
            ) {
              const deadToken = tokens[idx];
              await db.query('DELETE FROM user_devices WHERE fcm_token = $1', [deadToken]);
            }
          }
        });
      }
    } catch (error) {
      console.error(`Error sending push notification to user ${userId}:`, error.message);
    }
  },

  // 🚀 Send Push to multiple users (e.g. all ride participants)
  sendToUsers: async (userIds, title, body, data = {}) => {
    if (!isInitialized) {
      console.warn('⚠️ Push notification skipped: Firebase Admin SDK is not initialized on this server.');
      return;
    }
    if (!Array.isArray(userIds) || userIds.length === 0) return;

    try {
      const result = await db.query(
        'SELECT fcm_token FROM user_devices WHERE user_id = ANY($1::uuid[])',
        [userIds]
      );

      if (result.rows.length === 0) {
        console.log(`ℹ️ No registered FCM devices found for target users. Push skipped.`);
        return;
      }

      const tokens = result.rows.map(r => r.fcm_token);
      console.log(`🔔 Sending multicast push to ${tokens.length} target device tokens...`);

      const messagePayload = {
        notification: {
          title,
          body
        },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'automate_rides_channel',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        tokens
      };

      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      console.log(`✅ Multicast push sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);
    } catch (error) {
      console.error('Error sending multicast push notifications:', error.message);
    }
  }
};

module.exports = notificationService;
