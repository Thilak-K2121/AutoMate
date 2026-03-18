const db = require('../config/db');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs'); // Import bcryptjs

const ALLOWED_DOMAIN = '@bmsce.ac.in'; 

const authController = {
  // POST /api/auth/register
  // REPLACE the register function in authController.js
  register: async (req, res) => {
    try {
      // NEW: Extract gender from the request body
      const { name, email, password, phone, gender } = req.body;

      if (!email || !email.endsWith('@bmsce.ac.in')) {
        return res.status(403).json({ message: 'Only @bmsce.ac.in emails are allowed.' });
      }
      if (!password || password.length < 6) {
        return res.status(400).json({ message: 'Password must be at least 6 characters long.' });
      }

      const userCheck = await db.query('SELECT * FROM users WHERE email = $1', [email]);
      if (userCheck.rows.length > 0) {
        return res.status(400).json({ message: 'User already exists. Please log in.' });
      }

      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      // NEW: Insert gender into the database, default to 'Unspecified' if missing
      const userGender = gender || 'Unspecified';
      const newUser = await db.query(
        'INSERT INTO users (name, email, password, phone, gender) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, email, rating, gender',
        [name, email, hashedPassword, phone, userGender]
      );

      const token = jwt.sign(
        { id: newUser.rows[0].id },
        process.env.JWT_SECRET || 'fallback_super_secret_key',
        { expiresIn: '7d' }
      );

      res.status(201).json({ token, user: newUser.rows[0] });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error during registration.' });
    }
  },

  // POST /api/auth/login
  login: async (req, res) => {
    try {
      const { email, password } = req.body;

      if (!email || !password) return res.status(400).json({ message: 'Email and password are required.' });

      // 1. Find user in database
      const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'User not found. Please register.' });
      }

      const user = result.rows[0];

      // 2. Compare the provided password with the hashed password in the DB
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(401).json({ message: 'Invalid credentials.' });
      }

      // 3. Generate JWT Token
      const token = jwt.sign(
        { id: user.id },
        process.env.JWT_SECRET || 'fallback_super_secret_key',
        { expiresIn: '7d' }
      );

      // Remove password from the response object for security
      delete user.password;

      res.status(200).json({ token, user });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error during login.' });
    }
  },

  // GET /api/auth/me (Remains the same)
  getMe: async (req, res) => {
    try {
      const result = await db.query('SELECT id, name, email, phone, rating,gender FROM users WHERE id = $1', [req.user.id]);
      if (result.rows.length === 0) return res.status(404).json({ message: 'User not found.' });
      res.status(200).json({ user: result.rows[0] });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error fetching profile.' });
    }
  }
};

module.exports = authController;