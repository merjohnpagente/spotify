const { song, user } = require('../services');
const catchAsync = require('../utils/catchAsync');

const search = catchAsync(async (req, res) => {
  const { query } = req.query;
  const limit = parseInt(req.query.limit) || 20;
  const songs = await song.searchSongs(query, limit);
  if (req.userId) {
    user.addSearchHistory(req.userId, query).catch(() => {});
  }
  res.json({ results: songs });
});

const trending = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 30;
  const songs = await song.getTrendingSongs(limit);
  res.json({ results: songs });
});

const byGenre = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const songs = await song.getSongsByGenre(req.params.genre, limit);
  res.json({ results: songs });
});

const getById = catchAsync(async (req, res) => {
  const result = await song.getSongById(req.params.videoId);
  if (!result) return res.status(404).json({ error: 'Song not found' });
  res.json(result);
});

const stream = catchAsync(async (req, res) => {
  const { videoId } = req.params;
  const quality = req.query.quality || 'medium';
  const url = await song.getSongStreamUrl(videoId, quality);
  res.json({ videoId, streamUrl: url });
});

const recommendations = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 10;
  const songs = await song.getRecommendations(req.params.videoId, limit);
  res.json({ results: songs });
});

const like = catchAsync(async (req, res) => {
  await song.likeSong(req.userId, req.params.videoId);
  res.status(201).json({ message: 'Song liked' });
});

const unlike = catchAsync(async (req, res) => {
  await song.unlikeSong(req.userId, req.params.videoId);
  res.json({ message: 'Song unliked' });
});

const getLikedSongs = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  const songs = await song.getLikedSongs(req.userId, limit);
  res.json({ results: songs });
});

const addHistory = catchAsync(async (req, res) => {
  const { videoId } = req.params;
  const { playDuration, totalDuration } = req.body;
  await song.addToHistory(req.userId, videoId, playDuration, totalDuration);
  res.status(201).json({ message: 'History updated' });
});

const getHistory = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  const history = await song.getHistory(req.userId, limit);
  res.json({ results: history });
});

const clearHistory = catchAsync(async (req, res) => {
  await song.clearHistory(req.userId);
  res.json({ message: 'History cleared' });
});

const getStats = catchAsync(async (req, res) => {
  const stats = await song.getUserStats(req.userId);
  res.json(stats);
});

module.exports = {
  search,
  trending,
  byGenre,
  getById,
  stream,
  recommendations,
  like,
  unlike,
  getLikedSongs,
  addHistory,
  getHistory,
  clearHistory,
  getStats,
};