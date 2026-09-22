const { Pool } = require('pg');
require('dotenv').config();

// Check if Render provided a DATABASE_URL.
// If yes, use it with SSL.
// Otherwise use local Docker/Postgres settings.
const poolConfig = {
  ...(process.env.DATABASE_URL
    ? {
        connectionString: process.env.DATABASE_URL,
        ssl: {
          rejectUnauthorized: false,
        },
      }
    : {
        user: process.env.DB_USER || 'postgres',
        host: process.env.DB_HOST || 'localhost',
        database: process.env.DB_NAME || 'autoride',
        password: process.env.DB_PASSWORD || 'postgres',
        port: process.env.DB_PORT || 5432,
      }),
  max: 10, // Maximum pool connections
  idleTimeoutMillis: 30000, // Close idle connections after 30s
  connectionTimeoutMillis: 3000, // Return an error after 3s if connection could not be established
};

// Create a new PostgreSQL connection pool
const pool = new Pool(poolConfig);

// Test the connection
pool.on('connect', () => {
  console.log('✅ Connected to the PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle database client', err);
});

// 🚨 FORCE CREATE THE TABLE AND ADD RIDE_ID
pool.query(`
  CREATE TABLE IF NOT EXISTS notifications (
      id SERIAL PRIMARY KEY,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      icon_type VARCHAR(50) DEFAULT 'person',
      is_read BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS ride_id UUID REFERENCES rides(id) ON DELETE CASCADE;
`)
.then(() => console.log("✅ Notifications table verified with ride_id!"))
.catch(err => console.error("Database table creation error:", err));

// 🚨 CREATE BLOCKED PASSENGERS TABLE
pool.query(`
  CREATE TABLE IF NOT EXISTS blocked_passengers (
      id SERIAL PRIMARY KEY,
      ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(ride_id, user_id)
  );
`)
.then(() => console.log("✅ Blocked Passengers table verified!"))
.catch(err => console.error("Database table creation error:", err));

// 🚨 ADD PAYMENT MODE COLUMN TO RIDES & VERIFY INDEXES
pool.query(`
  ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(20) DEFAULT 'Any';

  -- Database performance indexes
  CREATE INDEX IF NOT EXISTS idx_rides_status_created_at ON rides(status, created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_rides_creator_id ON rides(creator_id);
  CREATE INDEX IF NOT EXISTS idx_ride_participants_ride_id ON ride_participants(ride_id);
  CREATE INDEX IF NOT EXISTS idx_ride_participants_user_id ON ride_participants(user_id);
  CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, is_read);
  CREATE INDEX IF NOT EXISTS idx_blocked_passengers ON blocked_passengers(ride_id, user_id);
  CREATE INDEX IF NOT EXISTS idx_messages_ride_id ON messages(ride_id, timestamp ASC);

  -- Purge orphaned messages and notifications for non-active rides on startup
  DELETE FROM notifications WHERE ride_id IS NOT NULL AND ride_id NOT IN (SELECT id FROM rides WHERE status IN ('active', 'full'));
  DELETE FROM messages WHERE ride_id IS NOT NULL AND ride_id NOT IN (SELECT id FROM rides WHERE status IN ('active', 'full'));
`)
.then(() => console.log("✅ Payment Mode column, indexes and cleanup verified!"))
.catch(err => console.error("Database table/index creation error:", err));

module.exports = {
  pool,
  query: (text, params) => pool.query(text, params),
  getClient: () => pool.connect(),
};