const dns = require('node:dns');
const config = require('./config');
const app = require('./app');
const { connectDB, disconnectDB } = require('./config/database');
const { connectRedis, disconnectRedis } = require('./config/redis');
const { initializeFirebase } = require('./config/firebase');

// Some local/corporate DNS servers refuse queries from Node's resolver (c-ares),
// which breaks mongodb+srv SRV lookups while browsers/nslookup still work.
// Prefer public resolvers; fall back to the OS-configured ones.
dns.setServers(['8.8.8.8', '1.1.1.1', ...dns.getServers()]);

let server = null;

const start = async () => {
  try {
    await connectDB();
    connectRedis();
    initializeFirebase();

    server = app.listen(config.port, () => {
      console.log(`API server running on port ${config.port} (${config.nodeEnv})`);
    });

    server.on('error', (error) => {
      console.error('Server error:', error);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

const shutdown = async (signal) => {
  console.log(`\n${signal} received, shutting down...`);
  if (server) {
    server.close(async () => {
      await disconnectRedis();
      await disconnectDB();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  } else {
    process.exit(0);
  }
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

start();