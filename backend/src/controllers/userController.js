const { user } = require('../services');
const catchAsync = require('../utils/catchAsync');

const follow = catchAsync(async (req, res) => {
  await user.followUser(req.userId, req.params.userId);
  res.status(201).json({ message: 'User followed' });
});

const unfollow = catchAsync(async (req, res) => {
  await user.unfollowUser(req.userId, req.params.userId);
  res.json({ message: 'User unfollowed' });
});

const getFollowers = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const result = await user.getFollowers(req.params.userId, limit);
  res.json(result);
});

const getFollowing = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const result = await user.getFollowing(req.params.userId, limit);
  res.json(result);
});

const getFollowingStatus = catchAsync(async (req, res) => {
  const isFollowing = await user.isFollowing(req.userId, req.params.userId);
  res.json({ isFollowing });
});

const getPublicProfile = catchAsync(async (req, res) => {
  const profile = await user.getPublicProfile(req.params.userId);
  res.json(profile);
});

const updateAvatar = catchAsync(async (req, res) => {
  const result = await user.updateAvatar(req.userId, req.file.buffer);
  res.json(result);
});

const getSearchHistory = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const history = await user.getSearchHistory(req.userId, limit);
  res.json({ results: history });
});

const deleteSearchHistoryEntry = catchAsync(async (req, res) => {
  await user.deleteSearchHistory(req.userId, req.params.historyId);
  res.json({ message: 'Search history entry deleted' });
});

const clearSearchHistory = catchAsync(async (req, res) => {
  await user.clearSearchHistory(req.userId);
  res.json({ message: 'Search history cleared' });
});

module.exports = {
  follow,
  unfollow,
  getFollowers,
  getFollowing,
  getFollowingStatus,
  getPublicProfile,
  updateAvatar,
  getSearchHistory,
  deleteSearchHistoryEntry,
  clearSearchHistory,
};