const rateLimit = require('express-rate-limit');
const config = require('../config');

const createRateLimiter = (windowMs, max, message) => {
  return rateLimit({
    windowMs,
    max,
    message: { error: message || 'Too many requests, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => req.ip,
    skip: () => config.nodeEnv === 'test',
  });
};

const globalLimiter = createRateLimiter(
  config.rateLimit.windowMs,
  config.rateLimit.maxRequests,
  'Too many requests from this IP'
);

const authLimiter = createRateLimiter(
  15 * 60 * 1000,
  10,
  'Too many authentication attempts, please try again later'
);

const searchLimiter = createRateLimiter(
  60 * 1000,
  10,
  'Too many search requests, please try again later'
);

const apiLimiter = createRateLimiter(
  60 * 1000,
  30,
  'Too many API requests, please try again later'
);

module.exports = {
  globalLimiter,
  authLimiter,
  searchLimiter,
  apiLimiter,
  createRateLimiter,
};