const { Pool } = require('pg');
require('dotenv').config();

// Create a new PostgreSQL connection pool
const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost', // Docker will override this later
  database: process.env.DB_NAME || 'autoride',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
});

// Test the connection
pool.on('connect', () => {
  console.log('Connected to the PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle database client', err);
  process.exit(-1);
});

// 🚨 FORCE CREATE THE TABLE IF DOCKER IGNORED IT
// 🚨 FORCE CREATE THE TABLE IF DOCKER IGNORED IT
// 🚨 FORCE CREATE THE TABLE IF DOCKER IGNORED IT
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
`).then(() => console.log("✅ Notifications table verified/created successfully!"))
  .catch(err => console.error("Database table creation error:", err));

module.exports = {
  query: (text, params) => pool.query(text, params),
};