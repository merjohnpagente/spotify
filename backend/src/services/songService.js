const mongoose = require('mongoose');
const { Song, UserLike, UserHistory, User } = require('../models');
const youtubeService = require('./youtubeService');
const deezerService = require('./deezerService');
const audiusService = require('./audiusService');
const { extractAudioUrl, incrementAccessCount } = require('./audioService');
const { cacheGet, cacheSet, cacheDeletePattern } = require('../config/redis');

const isDbReady = () => mongoose.connection.readyState === 1;
const ensureDb = () => {
  if (!isDbReady()) {
    const err = new Error('Database unavailable - please configure MongoDB Atlas IP whitelist');
    err.status = 503;
    err.statusCode = 503;
    throw err;
  }
};

const CACHE_TTL = {
  SONG: 7 * 24 * 60 * 60,
  TRENDING: 60 * 60,
  SEARCH: 24 * 60 * 60,
  RECOMMENDATIONS: 24 * 60 * 60,
};

// Persist a YouTube song in MongoDB; if the DB is unavailable, degrade
// gracefully and serve the YouTube data directly so music keeps playing.
const upsertSong = async (ytData) => {
  if (!isDbReady()) {
    return {
      id: null,
      isAvailable: true,
      addedToSystemAt: new Date(),
      ...ytData,
    };
  }
  try {
    let song = await Song.findOne({ videoId: ytData.videoId });
    if (!song) {
      song = await Song.create({ ...ytData, addedToSystemAt: new Date() });
    }
    return song.toPublicJSON();
  } catch (dbError) {
    console.warn('MongoDB unavailable, serving song without caching:', dbError.message);
    return {
      id: null,
      isAvailable: true,
      addedToSystemAt: new Date(),
      ...ytData,
    };
  }
};

const resolveSongById = async (videoId) => {
  // Try Deezer/Audius first (prefix), then YouTube
  if (videoId.startsWith('dz_')) {
    const dz = await deezerService.getSongById(videoId);
    if (dz) return dz;
  }
  if (videoId.startsWith('au_')) {
    const au = await audiusService.searchSongs(videoId.slice(3), 1);
    if (au.length && au[0].videoId === videoId) return au[0];
    // fallback: fetch via Audius trending search?
  }
  // Legacy YouTube 11-char or numeric fallback
  const yt = await youtubeService.getSongById(videoId);
  if (yt) return yt;
  if (videoId.startsWith('dz_') || videoId.startsWith('au_')) return null;
  // Try Deezer numeric without prefix
  if (/^\d+$/.test(videoId)) {
    const dz2 = await deezerService.getSongById(`dz_${videoId}`);
    if (dz2) return dz2;
  }
  return null;
};

const getOrCreateSong = async (videoId) => {
  if (!isDbReady()) {
    const data = await resolveSongById(videoId);
    if (!data) throw new Error('Song not found');
    return {
      toPublicJSON: () => ({
        id: null,
        isAvailable: true,
        addedToSystemAt: new Date(),
        ...data,
      }),
      videoId,
    };
  }
  let song = await Song.findOne({ videoId });
  
  if (!song) {
    const data = await resolveSongById(videoId);
    if (!data) throw new Error('Song not found');
    
    song = await Song.create({
      ...data,
      addedToSystemAt: new Date(),
    });
  }
  
  return song;
};

const searchSongsService = async (query, limit = 20) => {
  const cacheKey = `search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  // Hybrid: Deezer first (major catalog, no bot block, <800ms), then Audius, then YouTube fallback
  let results = [];
  try {
    const [deezerResults, audiusResults] = await Promise.all([
      deezerService.searchSongs(query, limit).catch(() => []),
      audiusService.searchSongs(query, Math.ceil(limit/2)).catch(() => []),
    ]);
    const seen = new Set();
    for (const bucket of [deezerResults, audiusResults]) {
      for (const s of bucket) {
        if (!seen.has(s.videoId) && results.length < limit) {
          seen.add(s.videoId);
          results.push(s);
        }
      }
    }
  } catch (_) { /* ignore */ }
  if (results.length < Math.min(limit, 5)) {
    try {
      const ytResults = await youtubeService.searchSongs(query, limit);
      const seen = new Set(results.map(r => r.videoId));
      for (const s of ytResults) {
        if (!seen.has(s.videoId) && results.length < limit) results.push(s);
      }
    } catch (_) { /* ignore */ }
  }

  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
};

const getTrendingSongsService = async (limit = 30) => {
  const cacheKey = `trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  let results = [];
  try {
    const [deezerTrending, audiusTrending] = await Promise.all([
      deezerService.getTrendingSongs(limit).catch(() => []),
      audiusService.getTrendingSongs(Math.ceil(limit/2)).catch(() => []),
    ]);
    const seen = new Set();
    for (const bucket of [deezerTrending, audiusTrending]) {
      for (const s of bucket) {
        if (!seen.has(s.videoId) && results.length < limit) {
          seen.add(s.videoId);
          results.push(s);
        }
      }
    }
  } catch (_) { /* ignore */ }
  if (results.length < Math.min(limit, 10)) {
    try {
      const ytResults = await youtubeService.getTrendingSongs(limit);
      const seen = new Set(results.map(r => r.videoId));
      for (const s of ytResults) if (!seen.has(s.videoId) && results.length < limit) results.push(s);
    } catch (_) { /* ignore */ }
  }

  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
  return songs;
};

const getSongByIdService = async (videoId) => {
  const cacheKey = `song:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  try {
    const song = await getOrCreateSong(videoId);
    const result = song.toPublicJSON();
    
    await cacheSet(cacheKey, result, CACHE_TTL.SONG);
    return result;
  } catch (dbError) {
    const data = await resolveSongById(videoId);
    if (!data) throw new Error('Song not found');
    console.warn('MongoDB unavailable, serving song:', dbError.message);
    return {
      id: null,
      isAvailable: true,
      addedToSystemAt: new Date(),
      ...data,
    };
  }
};

const getSongStreamUrl = async (videoId) => {
  // Don't block playback on DB counter — fire and forget
  incrementAccessCount(videoId).catch(() => {});
  return extractAudioUrl(videoId);
};

const getRecommendationsService = async (videoId, limit = 10) => {
  const cacheKey = `recommendations:${videoId}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  let recommendations = [];
  try {
    recommendations = await youtubeService.getRecommendations(videoId, limit);
  } catch (_) {
    // Fallback to Deezer search using song title
    try {
      const song = await resolveSongById(videoId);
      if (song) {
        const q = `${song.title} ${song.artist}`;
        recommendations = await deezerService.searchSongs(q, limit);
      }
    } catch (_) { /* ignore */ }
  }
  
  const songs = await Promise.all(recommendations.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.RECOMMENDATIONS);
  return songs;
};

const getSongsByGenre = async (genre, limit = 20) => {
  const cacheKey = `genre:${genre}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  let results = await deezerService.searchSongs(`${genre} music`, limit);
  if (!results.length) results = await youtubeService.searchByGenre(genre, limit);
  
  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
};

const likeSong = async (userId, videoId) => {
  ensureDb();
  await getOrCreateSong(videoId);
  
  const existing = await UserLike.findOne({ userId, videoId });
  if (existing) throw new Error('Already liked');

  await UserLike.create({ userId, videoId });
  
  await User.findByIdAndUpdate(userId, { $inc: { 'stats.likedSongsCount': 1 } });
  
  await cacheDeletePattern(`user:${userId}:liked*`);
  await cacheDeletePattern(`user:${userId}:stats*`);
};

const unlikeSong = async (userId, videoId) => {
  ensureDb();
  const result = await UserLike.deleteOne({ userId, videoId });
  if (result.deletedCount === 0) throw new Error('Not liked');

  await User.findByIdAndUpdate(userId, { $inc: { 'stats.likedSongsCount': -1 } });
  
  await cacheDeletePattern(`user:${userId}:liked*`);
  await cacheDeletePattern(`user:${userId}:stats*`);
};

const getLikedSongs = async (userId, limit = 50) => {
  ensureDb();
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
  ensureDb();
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
  ensureDb();
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
  ensureDb();
  await UserHistory.deleteMany({ userId });
  await cacheDeletePattern(`user:${userId}:history*`);
};

const getUserStats = async (userId) => {
  ensureDb();
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