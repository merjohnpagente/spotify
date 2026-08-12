const { verifyAccessToken } = require('../services/authService');
const { User } = require('../models');
const { cacheGet, cacheSet } = require('../config/redis');

const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    const cacheKey = `user:${decoded.uid}`;
    let user = await cacheGet(cacheKey);
    
    if (!user) {
      user = await User.findById(decoded.uid);
      if (!user) return res.status(401).json({ error: 'User not found' });
      if (user.accountStatus !== 'active') return res.status(403).json({ error: 'Account suspended' });
      await cacheSet(cacheKey, user.toPublicJSON(), 30 * 60);
    }

    req.user = user;
    req.userId = decoded.uid;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    console.error('Auth middleware error:', error);
    return res.status(500).json({ error: 'Authentication failed' });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyAccessToken(token);

    const cacheKey = `user:${decoded.uid}`;
    let user = await cacheGet(cacheKey);
    
    if (!user) {
      user = await User.findById(decoded.uid);
      if (user && user.accountStatus === 'active') {
        await cacheSet(cacheKey, user.toPublicJSON(), 30 * 60);
        req.user = user;
        req.userId = decoded.uid;
      }
    } else {
      req.user = user;
      req.userId = decoded.uid;
    }
    next();
  } catch (error) {
    next();
  }
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
    if (roles.length && !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Not authorized' });
    }
    next();
  };
};

module.exports = { authenticate, optionalAuth, authorize };