const express = require('express');
const authRoutes = require('./auth.routes');
const songRoutes = require('./song.routes');
const playlistRoutes = require('./playlist.routes');
const userRoutes = require('./user.routes');

const router = express.Router();

router.get('/status', (req, res) => {
  res.json({ status: 'ok', service: 'spotify-clone-api' });
});

router.use('/auth', authRoutes);
router.use('/songs', songRoutes);
router.use('/playlists', playlistRoutes);
router.use('/users', userRoutes);

module.exports = router;