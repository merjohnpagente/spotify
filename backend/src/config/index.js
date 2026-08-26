require('dotenv').config();

// Tolerate common paste mistakes in env values: surrounding quotes,
// backticks and stray whitespace break mongodb:// URIs otherwise.
const cleanEnv = (value) =>
  (value || '').trim().replace(/^["'`]+|["'`]+$/g, '').trim();

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 30000,
  
  mongodb: {
    uri: cleanEnv(process.env.MONGODB_URI) || undefined,
  },
  
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  },
  
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    accessExpiry: process.env.JWT_ACCESS_EXPIRY || '1h',
    refreshExpiry: process.env.JWT_REFRESH_EXPIRY || '30d',
  },
  
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
  },
  
  youtube: {
    ytDlpPath: process.env.YT_DLP_PATH || 'yt-dlp',
    trendingPlaylistUrl:
      process.env.TRENDING_PLAYLIST_URL ||
      'https://www.youtube.com/playlist?list=PL4fGSI1pDJn5kI81J1cQWv5U5y_WbJD9g',
  },
  
  redis: {
    url: process.env.REDIS_URL,
  },
  
  mailgun: {
    apiKey: process.env.MAILGUN_API_KEY,
    domain: process.env.MAILGUN_DOMAIN,
    fromEmail: process.env.MAILGUN_FROM_EMAIL,
  },
  
  frontend: {
    url: process.env.FRONTEND_URL || 'http://localhost:3000',
  },
  
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 60000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 50,
  },
  
  audio: {
    ytDlpPath: process.env.YT_DLP_PATH || 'yt-dlp',
    cacheTtlHours: parseInt(process.env.AUDIO_CACHE_TTL_HOURS) || 12,
  },
};