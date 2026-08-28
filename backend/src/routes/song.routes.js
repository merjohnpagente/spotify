const express = require('express');
const {
  authenticate,
  optionalAuth,
  searchLimiter,
  searchValidation,
  videoIdValidation,
  qualityValidation,
  historyValidation,
} = require('../middleware');
const songController = require('../controllers/songController');

const router = express.Router();

router.get('/search', optionalAuth, searchLimiter, searchValidation, songController.search);
router.get('/trending', optionalAuth, songController.trending);
router.get('/genre/:genre', optionalAuth, songController.byGenre);

router.get('/me/liked', authenticate, songController.getLikedSongs);
router.get('/me/history', authenticate, songController.getHistory);
router.delete('/me/history', authenticate, songController.clearHistory);
router.get('/me/stats', authenticate, songController.getStats);

router.get('/:videoId/recommendations', videoIdValidation, songController.recommendations);
router.get('/:videoId/stream', videoIdValidation, qualityValidation, songController.stream);
router.get('/:videoId/audio', videoIdValidation, qualityValidation, songController.audioProxy);
router.get('/:videoId', videoIdValidation, songController.getById);

router.post('/:videoId/like', authenticate, videoIdValidation, songController.like);
router.delete('/:videoId/like', authenticate, videoIdValidation, songController.unlike);
router.post('/:videoId/history', authenticate, historyValidation, songController.addHistory);

module.exports = router;