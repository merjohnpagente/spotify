const mongoose = require('mongoose');
const config = require('./index');

let isConnected = false;

const connectDB = async () => {
  if (isConnected) {
    console.log('MongoDB already connected');
    return;
  }

  try {
    if (!config.mongodb.uri || !/^mongodb(\+srv)?:\/\//.test(config.mongodb.uri)) {
      throw new Error(
        'MONGODB_URI is missing or malformed - it must start with "mongodb://" or "mongodb+srv://"'
      );
    }
    const conn = await mongoose.connect(config.mongodb.uri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      // Fail immediately when disconnected instead of buffering queries
      // forever - lets callers fall back to YouTube-only mode.
      bufferCommands: false,
    });

    isConnected = true;
    console.log(`MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error('MongoDB connection error:', error.message);
    throw error;
  }
};

const disconnectDB = async () => {
  if (!isConnected) return;
  await mongoose.disconnect();
  isConnected = false;
  console.log('MongoDB disconnected');
};

process.on('SIGINT', async () => {
  await disconnectDB();
  process.exit(0);
});

module.exports = { connectDB, disconnectDB };