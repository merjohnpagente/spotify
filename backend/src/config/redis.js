const Redis = require('ioredis');
const config = require('./index');

let redisClient = null;

const connectRedis = () => {
  if (redisClient) return redisClient;
  if (!config.redis.url) {
    console.warn('Redis not configured, caching disabled');
    return null;
  }

  try {
    redisClient = new Redis(config.redis.url, {
      maxRetriesPerRequest: 3,
      retryDelayOnFailover: 100,
      enableReadyCheck: true,
      lazyConnect: true,
    });

    redisClient.on('connect', () => {
      console.log('Redis connected');
    });

    redisClient.on('error', (err) => {
      console.error('Redis error:', err);
    });

    redisClient.on('close', () => {
      console.log('Redis connection closed');
    });

    redisClient.connect().catch(console.error);
    return redisClient;
  } catch (error) {
    console.error('Redis connection failed:', error);
    return null;
  }
};

const getRedis = () => redisClient;

const disconnectRedis = async () => {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
};

const cacheGet = async (key) => {
  if (!redisClient) return null;
  try {
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Cache get error:', error);
    return null;
  }
};

const cacheSet = async (key, value, ttlSeconds) => {
  if (!redisClient) return false;
  try {
    await redisClient.setex(key, ttlSeconds, JSON.stringify(value));
    return true;
  } catch (error) {
    console.error('Cache set error:', error);
    return false;
  }
};

const cacheDelete = async (key) => {
  if (!redisClient) return false;
  try {
    await redisClient.del(key);
    return true;
  } catch (error) {
    console.error('Cache delete error:', error);
    return false;
  }
};

const cacheDeletePattern = async (pattern) => {
  if (!redisClient) return false;
  try {
    const keys = await redisClient.keys(pattern);
    if (keys.length > 0) {
      await redisClient.del(...keys);
    }
    return true;
  } catch (error) {
    console.error('Cache delete pattern error:', error);
    return false;
  }
};

module.exports = {
  connectRedis,
  getRedis,
  disconnectRedis,
  cacheGet,
  cacheSet,
  cacheDelete,
  cacheDeletePattern,
};