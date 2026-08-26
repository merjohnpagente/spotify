const express = require('express');
const mongoose = require('mongoose');
const authRoutes = require('./auth.routes');
const songRoutes = require('./song.routes');
const playlistRoutes = require('./playlist.routes');
const userRoutes = require('./user.routes');

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

router.get('/debug/ytdlp', async (req, res, next) => {
  try {
    const { diagnose } = require('../services/youtubeService');
    res.json(await diagnose());
  } catch (error) {
    next(error);
  }
});

router.use('/auth', authRoutes);
router.use('/songs', songRoutes);
router.use('/playlists', playlistRoutes);
router.use('/users', userRoutes);

module.exports = router;