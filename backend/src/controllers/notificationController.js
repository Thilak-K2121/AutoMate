const db = require('../config/db');

const notificationController = {
  // Get all notifications for the logged-in user
  getUserNotifications: async (req, res) => {
    try {
      const userId = req.user.id;
      const result = await db.query(
        'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
        [userId]
      );
      res.status(200).json({ notifications: result.rows });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching notifications' });
    }
  },

  // Mark all as read (Optional, for later)
  markAsRead: async (req, res) => {
    try {
      const userId = req.user.id;
      await db.query('UPDATE notifications SET is_read = TRUE WHERE user_id = $1', [userId]);
      res.status(200).json({ message: 'Notifications marked as read' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error updating notifications' });
    }
  }
};

module.exports = notificationController;