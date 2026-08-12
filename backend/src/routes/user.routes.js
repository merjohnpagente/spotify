const express = require('express');
const {
  authenticate,
  uploadAvatar,
  handleUploadError,
  userIdValidation,
  historyIdValidation,
} = require('../middleware');
const userController = require('../controllers/userController');

const router = express.Router();

router.post('/me/avatar', authenticate, uploadAvatar, handleUploadError, userController.updateAvatar);
router.get('/me/search-history', authenticate, userController.getSearchHistory);
router.delete('/me/search-history/:historyId', authenticate, historyIdValidation, userController.deleteSearchHistoryEntry);
router.delete('/me/search-history', authenticate, userController.clearSearchHistory);

router.get('/:userId/profile', userIdValidation, userController.getPublicProfile);
router.post('/:userId/follow', authenticate, userIdValidation, userController.follow);
router.delete('/:userId/follow', authenticate, userIdValidation, userController.unfollow);
router.get('/:userId/following-status', authenticate, userIdValidation, userController.getFollowingStatus);
router.get('/:userId/followers', userIdValidation, userController.getFollowers);
router.get('/:userId/following', userIdValidation, userController.getFollowing);

module.exports = router;