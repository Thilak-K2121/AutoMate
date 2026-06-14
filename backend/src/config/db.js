const { Pool } = require('pg');
require('dotenv').config();

// Check if Render provided a DATABASE_URL.
// If yes, use it with SSL.
// Otherwise use local Docker/Postgres settings.
const poolConfig = process.env.DATABASE_URL
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
    };

// Create a new PostgreSQL connection pool
const pool = new Pool(poolConfig);

// Test the connection
pool.on('connect', () => {
  console.log('✅ Connected to the PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle database client', err);
  process.exit(-1);
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

// 🚨 ADD PAYMENT MODE COLUMN TO RIDES
pool.query(`
  ALTER TABLE rides
  ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(20) DEFAULT 'Any';
`)
.then(() => console.log("✅ Payment Mode column verified!"))
.catch(err => console.error("Database table creation error:", err));

module.exports = {
  query: (text, params) => pool.query(text, params),
};