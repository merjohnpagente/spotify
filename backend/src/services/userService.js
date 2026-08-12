const { User, Follower, SearchHistory, Playlist } = require('../models');
const { uploadAvatar, deleteAvatar } = require('./imageService');
const { cacheGet, cacheSet, cacheDelete, cacheDeletePattern } = require('../config/redis');
const { sendFollowNotification } = require('./emailService');

const followUser = async (followerId, followingId) => {
  if (followerId === followingId) throw new Error('Cannot follow yourself');

  const existing = await Follower.findOne({ followerId, followingId });
  if (existing) throw new Error('Already following');

  await Follower.create({ followerId, followingId });
  
  await User.findByIdAndUpdate(followingId, { $inc: { 'stats.followerCount': 1 } });
  await User.findByIdAndUpdate(followerId, { $inc: { 'stats.followingCount': 1 } });

  const follower = await User.findById(followerId);
  const following = await User.findById(followingId);
  
  if (following?.preferences?.notifications && following.email) {
    await sendFollowNotification(following.email, follower.username);
  }

  await cacheDeletePattern(`user:${followerId}:following*`);
  await cacheDeletePattern(`user:${followingId}:followers*`);
  await cacheDeletePattern(`user:${followerId}:stats*`);
  await cacheDeletePattern(`user:${followingId}:stats*`);
};

const unfollowUser = async (followerId, followingId) => {
  const result = await Follower.deleteOne({ followerId, followingId });
  if (result.deletedCount === 0) throw new Error('Not following');

  await User.findByIdAndUpdate(followingId, { $inc: { 'stats.followerCount': -1 } });
  await User.findByIdAndUpdate(followerId, { $inc: { 'stats.followingCount': -1 } });

  await cacheDeletePattern(`user:${followerId}:following*`);
  await cacheDeletePattern(`user:${followingId}:followers*`);
  await cacheDeletePattern(`user:${followerId}:stats*`);
  await cacheDeletePattern(`user:${followingId}:stats*`);
};

const getFollowers = async (userId, limit = 20) => {
  const cacheKey = `user:${userId}:followers:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const followers = await Follower.find({ followingId: userId })
    .populate('followerId', 'username firstName lastName avatarUrl')
    .sort({ followedAt: -1 })
    .limit(limit);

  const result = followers.map(f => ({
    user: f.followerId.toPublicJSON(),
    followedAt: f.followedAt,
  }));
  const total = await Follower.countDocuments({ followingId: userId });

  await cacheSet(cacheKey, { followers: result, total }, 5 * 60);
  return { followers: result, total };
};

const getFollowing = async (userId, limit = 20) => {
  const cacheKey = `user:${userId}:following:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const following = await Follower.find({ followerId: userId })
    .populate('followingId', 'username firstName lastName avatarUrl')
    .sort({ followedAt: -1 })
    .limit(limit);

  const result = following.map(f => ({
    user: f.followingId.toPublicJSON(),
    followedAt: f.followedAt,
  }));
  const total = await Follower.countDocuments({ followerId: userId });

  await cacheSet(cacheKey, { following: result, total }, 5 * 60);
  return { following: result, total };
};

const isFollowing = async (followerId, followingId) => {
  const follow = await Follower.findOne({ followerId, followingId });
  return !!follow;
};

const addSearchHistory = async (userId, query) => {
  if (!query.trim()) return;
  
  await SearchHistory.create({ userId, query: query.trim() });
  await cacheDeletePattern(`user:${userId}:search-history*`);
};

const getSearchHistory = async (userId, limit = 20) => {
  const cacheKey = `user:${userId}:search-history:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const history = await SearchHistory.find({ userId })
    .sort({ searchedAt: -1 })
    .limit(limit);

  const result = history.map(h => ({ query: h.query, searchedAt: h.searchedAt }));
  await cacheSet(cacheKey, result, 5 * 60);
  return result;
};

const deleteSearchHistory = async (userId, historyId) => {
  await SearchHistory.findOneAndDelete({ _id: historyId, userId });
  await cacheDeletePattern(`user:${userId}:search-history*`);
};

const clearSearchHistory = async (userId) => {
  await SearchHistory.deleteMany({ userId });
  await cacheDeletePattern(`user:${userId}:search-history*`);
};

const updateAvatar = async (userId, fileBuffer) => {
  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  if (user.avatarUrl) {
    const publicId = user.avatarUrl.split('/').pop()?.split('.')[0];
    if (publicId) await deleteAvatar(`spotify-clone/avatars/${publicId}`);
  }

  const result = await uploadAvatar(fileBuffer);
  user.avatarUrl = result.secure_url;
  await user.save();

  await cacheDelete(`user:${userId}`);
  return user.toPublicJSON();
};

const getPublicProfile = async (userId) => {
  const cacheKey = `public-profile:${userId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  const followerCount = await Follower.countDocuments({ followingId: userId });
  const followingCount = await Follower.countDocuments({ followerId: userId });
  const playlistCount = await Playlist.countDocuments({ userId, isPublic: true });

  const result = {
    ...user.toPublicJSON(),
    followerCount,
    followingCount,
    playlistCount,
  };

  await cacheSet(cacheKey, result, 5 * 60);
  return result;
};

module.exports = {
  followUser,
  unfollowUser,
  getFollowers,
  getFollowing,
  isFollowing,
  addSearchHistory,
  getSearchHistory,
  deleteSearchHistory,
  clearSearchHistory,
  updateAvatar,
  getPublicProfile,
};