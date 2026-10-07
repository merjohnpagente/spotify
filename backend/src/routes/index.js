const express = require('express');
const mongoose = require('mongoose');
const config = require('../config');
const authRoutes = require('./auth.routes');
const songRoutes = require('./song.routes');
const playlistRoutes = require('./playlist.routes');
const userRoutes = require('./user.routes');
const { authenticate } = require('../middleware');

const router = express.Router();

router.get('/status', (req, res) => {
  const states = ['disconnected', 'connected', 'connecting', 'disconnecting'];
  res.json({
    status: 'ok',
    service: 'spotify-clone-api',
    database: {
      // Boolean only - never expose the URI itself.
      uriConfigured: Boolean(process.env.MONGODB_URI),
      state: states[mongoose.connection.readyState] || 'unknown',
    },
    uptime: process.uptime(),
  });
});

router.get('/debug/ytdlp', authenticate, async (req, res, next) => {
  // Spawns real yt-dlp processes — never expose to the open internet.
  // Disabled in production unless explicitly enabled for troubleshooting.
  if (config.nodeEnv === 'production' && process.env.ENABLE_DEBUG !== 'true') {
    return res.status(403).json({ error: 'Debug endpoint disabled in production' });
  }
  try {
    const { diagnose } = require('../services/youtubeService');
    res.json(
      await diagnose({
        videoId: req.query.videoId,
        strategy: req.query.strategy,
      })
    );
  } catch (error) {
    next(error);
  }
});

router.use('/auth', authRoutes);
router.use('/songs', songRoutes);
router.use('/playlists', playlistRoutes);
router.use('/users', userRoutes);

module.exports = router;