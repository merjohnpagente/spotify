const { Song, UserLike, UserHistory, User } = require('../models');
const { searchSongs, getTrendingSongs, getSongById, getRecommendations, searchByGenre } = require('./youtubeService');
const { extractAudioUrl, incrementAccessCount } = require('./audioService');
const { cacheGet, cacheSet, cacheDeletePattern } = require('../config/redis');

const CACHE_TTL = {
  SONG: 7 * 24 * 60 * 60,
  TRENDING: 60 * 60,
  SEARCH: 24 * 60 * 60,
  RECOMMENDATIONS: 24 * 60 * 60,
};

const getOrCreateSong = async (videoId) => {
  let song = await Song.findOne({ videoId });
  
  if (!song) {
    const youtubeData = await getSongById(videoId);
    if (!youtubeData) throw new Error('Song not found on YouTube');
    
    song = await Song.create({
      ...youtubeData,
      addedToSystemAt: new Date(),
    });
  }
  
  return song;
};

const searchSongsService = async (query, limit = 20) => {
  const cacheKey = `search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const youtubeResults = await searchSongs(query, limit);
  
  const songs = [];
  for (const ytSong of youtubeResults) {
    let song = await Song.findOne({ videoId: ytSong.videoId });
    if (!song) {
      song = await Song.create({ ...ytSong, addedToSystemAt: new Date() });
    }
    songs.push(song.toPublicJSON());
  }

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
};

const getTrendingSongsService = async (limit = 30) => {
  const cacheKey = `trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const youtubeResults = await getTrendingSongs(limit);
  
  const songs = [];
  for (const ytSong of youtubeResults) {
    let song = await Song.findOne({ videoId: ytSong.videoId });
    if (!song) {
      song = await Song.create({ ...ytSong, addedToSystemAt: new Date() });
    }
    songs.push(song.toPublicJSON());
  }

  await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
  return songs;
};

const getSongByIdService = async (videoId) => {
  const cacheKey = `song:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const song = await getOrCreateSong(videoId);
  const result = song.toPublicJSON();
  
  await cacheSet(cacheKey, result, CACHE_TTL.SONG);
  return result;
};

const getSongStreamUrl = async (videoId) => {
  await incrementAccessCount(videoId);
  return extractAudioUrl(videoId);
};

const getRecommendationsService = async (videoId, limit = 10) => {
  const cacheKey = `recommendations:${videoId}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const recommendations = await getRecommendations(videoId, limit);
  
  const songs = [];
  for (const rec of recommendations) {
    let song = await Song.findOne({ videoId: rec.videoId });
    if (!song) {
      song = await Song.create({ ...rec, addedToSystemAt: new Date() });
    }
    songs.push(song.toPublicJSON());
  }

  await cacheSet(cacheKey, songs, CACHE_TTL.RECOMMENDATIONS);
  return songs;
};

const getSongsByGenre = async (genre, limit = 20) => {
  const cacheKey = `genre:${genre}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const youtubeResults = await searchByGenre(genre, limit);
  
  const songs = [];
  for (const ytSong of youtubeResults) {
    let song = await Song.findOne({ videoId: ytSong.videoId });
    if (!song) {
      song = await Song.create({ ...ytSong, addedToSystemAt: new Date() });
    }
    songs.push(song.toPublicJSON());
  }

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
};

const likeSong = async (userId, videoId) => {
  await getOrCreateSong(videoId);
  
  const existing = await UserLike.findOne({ userId, videoId });
  if (existing) throw new Error('Already liked');

  await UserLike.create({ userId, videoId });
  
  await User.findByIdAndUpdate(userId, { $inc: { 'stats.likedSongsCount': 1 } });
  
  await cacheDeletePattern(`user:${userId}:liked*`);
  await cacheDeletePattern(`user:${userId}:stats*`);
};

const unlikeSong = async (userId, videoId) => {
  const result = await UserLike.deleteOne({ userId, videoId });
  if (result.deletedCount === 0) throw new Error('Not liked');

  await User.findByIdAndUpdate(userId, { $inc: { 'stats.likedSongsCount': -1 } });
  
  await cacheDeletePattern(`user:${userId}:liked*`);
  await cacheDeletePattern(`user:${userId}:stats*`);
};

const getLikedSongs = async (userId, limit = 50) => {
  const cacheKey = `user:${userId}:liked:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const likes = await UserLike.find({ userId }).sort({ likedAt: -1 }).limit(limit);
  const videoIds = likes.map(l => l.videoId);
  
  const songs = [];
  for (const videoId of videoIds) {
    const song = await getOrCreateSong(videoId);
    songs.push(song.toPublicJSON());
  }

  await cacheSet(cacheKey, songs, 5 * 60);
  return songs;
};

const addToHistory = async (userId, videoId, playDuration, totalDuration) => {
  await getOrCreateSong(videoId);
  
  const completed = playDuration >= totalDuration * 0.9;
  
  await UserHistory.create({
    userId,
    videoId,
    playDuration,
    completed,
  });

  await User.findByIdAndUpdate(userId, {
    $inc: { 
      'stats.totalSongsPlayed': 1,
      'stats.totalListeningTime': playDuration,
    },
  });

  await cacheDeletePattern(`user:${userId}:history*`);
  await cacheDeletePattern(`user:${userId}:stats*`);
};

const getHistory = async (userId, limit = 50) => {
  const cacheKey = `user:${userId}:history:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const history = await UserHistory.find({ userId }).sort({ playedAt: -1 }).limit(limit);
  
  const songs = [];
  for (const entry of history) {
    const song = await getOrCreateSong(entry.videoId);
    songs.push({
      ...song.toPublicJSON(),
      playDuration: entry.playDuration,
      completed: entry.completed,
      playedAt: entry.playedAt,
    });
  }

  await cacheSet(cacheKey, songs, 5 * 60);
  return songs;
};

const clearHistory = async (userId) => {
  await UserHistory.deleteMany({ userId });
  await cacheDeletePattern(`user:${userId}:history*`);
};

const getUserStats = async (userId) => {
  const cacheKey = `user:${userId}:stats`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  const history = await UserHistory.find({ userId });

  const genreCount = {};
  const artistCount = {};
  const songCount = {};

  for (const entry of history) {
    const song = await Song.findOne({ videoId: entry.videoId });
    if (song) {
      genreCount[song.genre] = (genreCount[song.genre] || 0) + 1;
      artistCount[song.artist] = (artistCount[song.artist] || 0) + 1;
      songCount[song.videoId] = (songCount[song.videoId] || 0) + 1;
    }
  }

  const topGenres = Object.entries(genreCount).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([genre, count]) => ({ genre, count }));
  const topArtists = Object.entries(artistCount).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([artist, count]) => ({ artist, count }));
  const topSongs = Object.entries(songCount).sort((a, b) => b[1] - a[1]).slice(0, 5).map(async ([videoId, count]) => {
    const song = await Song.findOne({ videoId });
    return song ? { ...song.toPublicJSON(), playCount: count } : null;
  });

  const stats = {
    totalListeningTime: user.stats.totalListeningTime,
    totalSongsPlayed: user.stats.totalSongsPlayed,
    likedSongsCount: user.stats.likedSongsCount,
    topGenres,
    topArtists,
    topSongs: (await Promise.all(topSongs)).filter(Boolean),
  };

  await cacheSet(cacheKey, stats, 30 * 60);
  return stats;
};

module.exports = {
  searchSongs: searchSongsService,
  getTrendingSongs: getTrendingSongsService,
  getSongById: getSongByIdService,
  getSongStreamUrl,
  getRecommendations: getRecommendationsService,
  getSongsByGenre,
  likeSong,
  unlikeSong,
  getLikedSongs,
  addToHistory,
  getHistory,
  clearHistory,
  getUserStats,
};