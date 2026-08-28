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

// In-memory fallback when REDIS_URL not set (Render free) — same API, zero infra.
const memCache = new Map(); // key -> {v, exp}
const memGet = (key) => {
  const e = memCache.get(key);
  if (!e) return null;
  if (Date.now() > e.exp) { memCache.delete(key); return null; }
  return e.v;
};
const memSet = (key, v, ttl) => {
  if (memCache.size > 500) { // cap
    const first = memCache.keys().next().value;
    if (first) memCache.delete(first);
  }
  memCache.set(key, { v, exp: Date.now() + ttl * 1000 });
};

const cacheGet = async (key) => {
  if (redisClient) {
    try {
      const data = await redisClient.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      console.error('Cache get error:', error);
    }
  }
  return memGet(key);
};

const cacheSet = async (key, value, ttlSeconds) => {
  if (redisClient) {
    try {
      await redisClient.setex(key, ttlSeconds, JSON.stringify(value));
      return true;
    } catch (error) {
      console.error('Cache set error:', error);
    }
  }
  memSet(key, value, ttlSeconds);
  return true;
};

const cacheDelete = async (key) => {
  if (redisClient) {
    try { await redisClient.del(key); return true; } catch (e) { console.error(e); }
  }
  memCache.delete(key);
  return true;
};

const cacheDeletePattern = async (pattern) => {
  if (redisClient) {
    try {
      const keys = await redisClient.keys(pattern);
      if (keys.length > 0) await redisClient.del(...keys);
      return true;
    } catch (error) { console.error(error); }
  }
  // mem wildcard
  const rx = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
  for (const k of [...memCache.keys()]) if (rx.test(k)) memCache.delete(k);
  return true;
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