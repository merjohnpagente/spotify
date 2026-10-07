const mongoose = require('mongoose');
const { Song, UserLike, UserHistory, User } = require('../models');
const youtubeService = require('./youtubeService');
const deezerService = require('./deezerService');
const audiusService = require('./audiusService');
const { extractAudioUrl, incrementAccessCount, clearAudioCache } = require('./audioService');
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

// YouTube yt-dlp search is slow on free-tier hosts (5-15s), but it is the
// ONLY source of full-length songs. Deezer (`dz_`) is always a 30s preview,
// so YouTube + Audius (full tracks) must come first and Deezer only fills
// gaps — otherwise search/playback is all 30s previews.
const YT_SEARCH_TIMEOUT_MS = 15000;

// Race a promise against a timeout so a slow source never blocks search.
const withTimeout = (promise, ms, fallback = []) =>
  Promise.race([
    promise,
    new Promise((res) => setTimeout(() => res(fallback), ms)),
  ]);

// Merge source buckets in priority order, deduped by videoId, up to limit.
const mergeDedupe = (buckets, limit) => {
  const seen = new Set();
  const out = [];
  for (const bucket of buckets) {
    for (const s of bucket || []) {
      if (s && s.videoId && !seen.has(s.videoId) && out.length < limit) {
        seen.add(s.videoId);
        out.push(s);
      }
    }
  }
  return out;
};

// Persist a YouTube song in MongoDB; if the DB is unavailable, degrade
// gracefully and serve the YouTube data directly so music keeps playing.
const upsertSong = async (ytData) => {
  const publicData = {
    id: null,
    isAvailable: true,
    addedToSystemAt: new Date(),
    source: ytData.source || (ytData.videoId && ytData.videoId.startsWith('dz_') ? 'deezer' : ytData.videoId && ytData.videoId.startsWith('au_') ? 'audius' : 'youtube'),
    isPreview: ytData.isPreview ?? (ytData.videoId && ytData.videoId.startsWith('dz_')),
    ...ytData,
  };
  if (!isDbReady()) {
    return publicData;
  }
  try {
    let song = await Song.findOne({ videoId: ytData.videoId });
    if (!song) {
      song = await Song.create({ ...ytData, addedToSystemAt: new Date() });
    }
    return song.toPublicJSON();
  } catch (dbError) {
    console.warn('MongoDB unavailable, serving song without caching:', dbError.message);
    return publicData;
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

// In-flight coalescing: concurrent identical requests share one promise so
// a remount/double-tap never spawns duplicate yt-dlp processes.
const pending = new Map();
const coalesce = (key, fn) => {
  const existing = pending.get(key);
  if (existing) return existing;
  const p = fn().finally(() => {
    if (pending.get(key) === p) pending.delete(key);
  });
  pending.set(key, p);
  return p;
};

const searchSongsService = async (query, limit = 20) => {
  const cacheKey = `search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  return coalesce(cacheKey, async () => {

  // YouTube FIRST (full songs) + Audius (full tracks) in parallel, Deezer
  // 30s previews only as last fill to reach `limit`.
  const [ytResults, audiusResults, deezerResults] = await Promise.all([
    withTimeout(
      youtubeService.searchSongs(query, limit).catch(() => []),
      YT_SEARCH_TIMEOUT_MS
    ),
    audiusService.searchSongs(query, limit).catch(() => []),
    deezerService.searchSongs(query, limit).catch(() => []),
  ]);

  const full = mergeDedupe([ytResults, audiusResults], limit);
  const seen = new Set(full.map((s) => s.videoId));
  const previews = (deezerResults || []).filter((s) => s && !seen.has(s.videoId));
  const results = [...full, ...previews].slice(0, limit);

  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
  });
};

const getTrendingSongsService = async (limit = 30) => {
  const cacheKey = `trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  return coalesce(cacheKey, async () => {

  // YouTube + Audius full tracks first, Deezer 30s previews only as fill.
  const [ytResults, audiusTrending, deezerTrending] = await Promise.all([
    withTimeout(
      youtubeService.getTrendingSongs(limit).catch(() => []),
      YT_SEARCH_TIMEOUT_MS
    ),
    audiusService.getTrendingSongs(limit).catch(() => []),
    deezerService.getTrendingSongs(limit).catch(() => []),
  ]);

  const full = mergeDedupe([ytResults, audiusTrending], limit);
  const seen = new Set(full.map((s) => s.videoId));
  const previews = (deezerTrending || []).filter((s) => s && !seen.has(s.videoId));
  const results = [...full, ...previews].slice(0, limit);

  if (!results.length) throw new Error('Failed to load trending songs');

  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
  return songs;
  });
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

  return coalesce(cacheKey, async () => {

  // YouTube + Audius full tracks first, Deezer 30s previews only as fill.
  const [ytResults, audiusResults, deezerResults] = await Promise.all([
    withTimeout(
      youtubeService.searchByGenre(genre, limit).catch(() => []),
      YT_SEARCH_TIMEOUT_MS
    ),
    audiusService.searchSongs(`${genre} music`, limit).catch(() => []),
    deezerService.searchSongs(`${genre} music`, limit).catch(() => []),
  ]);

  const full = mergeDedupe([ytResults, audiusResults], limit);
  const seen = new Set(full.map((s) => s.videoId));
  const previews = (deezerResults || []).filter((s) => s && !seen.has(s.videoId));
  // Keep the old ">=3 full else fill with previews" spirit so niche genres
  // still return something instead of an empty screen.
  const results = full.length >= Math.min(limit, 3)
    ? full
    : [...full, ...previews].slice(0, limit);

  const songs = await Promise.all(results.map(r => upsertSong(r)));

  await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
  return songs;
  });
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
  clearAudioCache,
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