const jwt = require('jsonwebtoken');

const verifyToken = (req, res, next) => {
  // Get the token from the Authorization header (format: "Bearer <token>")
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Access Denied. No token provided.' });
  }

  try {
    // Verify token using secret key from environment variables
    const verified = jwt.verify(token, process.env.JWT_SECRET || 'fallback_super_secret_key');
    
    // Attach the decoded user data (like user ID) to the request object
    req.user = verified; 
    
    // Proceed to the next middleware or route handler
    next();
  } catch (error) {
    res.status(403).json({ message: 'Invalid or expired token.' });
  }
};

module.exports = verifyToken;