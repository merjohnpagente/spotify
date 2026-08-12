const express = require('express');
const {
  authenticate,
  optionalAuth,
  playlistValidation,
  updatePlaylistValidation,
  addSongValidation,
  playlistIdValidation,
  videoIdValidation,
  reorderValidation,
} = require('../middleware');
const playlistController = require('../controllers/playlistController');

const router = express.Router();

router.post('/', authenticate, playlistValidation, playlistController.create);
router.get('/', authenticate, playlistController.getMyPlaylists);

router.get('/:playlistId', optionalAuth, playlistIdValidation, playlistController.getById);
router.patch('/:playlistId', authenticate, playlistIdValidation, updatePlaylistValidation, playlistController.update);
router.delete('/:playlistId', authenticate, playlistIdValidation, playlistController.remove);

router.get('/:playlistId/songs', playlistIdValidation, playlistController.getPlaylistSongs);
router.post('/:playlistId/songs', authenticate, playlistIdValidation, addSongValidation, playlistController.addSong);
router.delete('/:playlistId/songs/:videoId', authenticate, playlistIdValidation, videoIdValidation, playlistController.removeSong);
router.put('/:playlistId/songs/reorder', authenticate, playlistIdValidation, reorderValidation, playlistController.reorder);

module.exports = router;