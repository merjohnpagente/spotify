const fs = require('fs');
const { execFile } = require('child_process');
const config = require('../config');
const { cacheGet, cacheSet } = require('../config/redis');

const CACHE_TTL = {
  SEARCH: 24 * 60 * 60,
  VIDEO: 7 * 24 * 60 * 60,
  TRENDING: 60 * 60,
  RECOMMENDATIONS: 24 * 60 * 60,
};

// Prefer an explicitly configured binary (YT_DLP_PATH) so deploys can ship
// a fresh yt-dlp - YouTube extraction breaks quickly with stale versions.
// The custom binary is probed once (`--version`); if it is broken we fall
// back to the yt-dlp-exec module binary automatically.
const configuredBinary = config.audio.ytDlpPath || config.youtube.ytDlpPath || '';
const customBinaryExists = configuredBinary && fs.existsSync(configuredBinary);
const ytDlpModule = require('yt-dlp-exec');

let binaryChoicePromise = null;
const resolveBinary = () => {
  if (!binaryChoicePromise) {
    binaryChoicePromise = (async () => {
      if (customBinaryExists) {
        try {
          const version = await new Promise((resolve, reject) => {
            execFile(configuredBinary, ['--version'], { timeout: 20000 }, (err, stdout) => {
              if (err) reject(err);
              else resolve(String(stdout).trim());
            });
          });
          console.log(`yt-dlp: using configured binary ${configuredBinary} (v${version})`);
          return { runner: ytDlpModule.create(configuredBinary), label: configuredBinary };
        } catch (error) {
          console.warn(`yt-dlp: configured binary probe failed (${error.message}), falling back to module binary`);
        }
      }
      console.log('yt-dlp: using yt-dlp-exec module binary');
      return { runner: ytDlpModule, label: 'module' };
    })();
  }
  return binaryChoicePromise;
};

let activeRunner = null;
const getRunner = async () => {
  if (!activeRunner) activeRunner = await resolveBinary();
  return activeRunner;
};

const YTDLP_BIN = configuredBinary || 'yt-dlp';
const TRENDING_PLAYLIST_URL = config.youtube.trendingPlaylistUrl;

const VIDEO_ID_PATTERN = /^[a-zA-Z0-9_-]{11}$/;

let activeProcesses = 0;
const pendingQueue = [];
const MAX_CONCURRENT_PROCESSES = 3;

const acquire = () => new Promise((resolve) => {
  if (activeProcesses < MAX_CONCURRENT_PROCESSES) {
    activeProcesses++;
    resolve();
  } else {
    pendingQueue.push(resolve);
  }
});

const release = () => {
  activeProcesses--;
  const next = pendingQueue.shift();
  if (next) {
    activeProcesses++;
    next();
  }
};

const runWithRunner = (runner, url, options) => {
  let timer;
  return Promise.race([
    runner(url, {
      dumpSingleJson: true,
      noWarnings: true,
      noCallHome: true,
      noCheckCertificate: true,
      socketTimeout: 30,
      ...options,
    }),
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('yt-dlp timed out')), 90000);
    }),
  ]).finally(() => clearTimeout(timer));
};

const runYtDlp = async (url, options = {}) => {
  await acquire();
  try {
    const primary = await getRunner();
    try {
      return await runWithRunner(primary.runner, url, options);
    } catch (primaryError) {
      // If the configured binary misbehaves, retry once with the module's
      // own binary and stick with it while it keeps working.
      if (primary.label !== 'module') {
        console.warn(`yt-dlp: configured binary failed ("${primaryError.message}"), retrying with module binary`);
        const fallback = { runner: ytDlpModule, label: 'module' };
        const result = await runWithRunner(fallback.runner, url, options);
        activeRunner = fallback;
        return result;
      }
      throw primaryError;
    }
  } finally {
    release();
  }
};

// Deep diagnostic used by GET /api/debug/ytdlp - tells us exactly which
// binary is in play and whether a minimal search works right now.
const diagnose = async () => {
  const started = Date.now();
  const active = await getRunner();
  const out = {
    configuredBinary: configuredBinary || null,
    configuredBinaryExists: customBinaryExists,
    usingBinary: active.label,
    search: null,
    durationMs: null,
  };
  try {
    const songs = await searchSongs('adele hello', 1);
    out.search = songs.length ? 'ok' : 'empty';
  } catch (error) {
    out.search = `failed: ${error.message}`;
  }
  out.durationMs = Date.now() - started;
  return out;
};

const searchSongs = async (query, limit = 20) => {
  const cacheKey = `search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  try {
    const data = await runYtDlp(`ytsearch${limit}:${query}`, {
      flatPlaylist: true,
      noPlaylist: true,
    });

    const entries = Array.isArray(data.entries) ? data.entries : [];
    const songs = entries
      .map(formatFlatEntry)
      .filter((s) => s && s.videoId && VIDEO_ID_PATTERN.test(s.videoId))
      .slice(0, limit);

    if (!songs.length) throw new Error('No results found');

    await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
    return songs;
  } catch (error) {
    console.error('yt-dlp search error:', error.message);
    throw new Error('Search failed');
  }
};

const getSongById = async (videoId) => {
  const cacheKey = `video:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  try {
    const data = await runYtDlp(`https://www.youtube.com/watch?v=${videoId}`, {
      skipDownload: true,
      noPlaylist: true,
    });

    if (!data || !data.id) return null;

    const song = formatVideoDetail(data);
    await cacheSet(cacheKey, song, CACHE_TTL.VIDEO);
    return song;
  } catch (error) {
    console.error('yt-dlp video detail error:', error.message);
    return null;
  }
};

const getTrendingSongs = async (limit = 30) => {
  const cacheKey = `trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  let songs = [];

  try {
    const data = await runYtDlp(TRENDING_PLAYLIST_URL, {
      flatPlaylist: true,
      playlistEnd: Math.min(limit, 50),
    });

    const entries = Array.isArray(data.entries) ? data.entries : [];
    songs = entries
      .map(formatFlatEntry)
      .filter((s) => s && s.videoId && VIDEO_ID_PATTERN.test(s.videoId))
      .slice(0, limit);
  } catch (error) {
    console.error('yt-dlp trending playlist error:', error.message);
  }

  if (songs.length < 5) {
    const fallbackQueries = ['top hits', 'trending music', 'popular songs'];
    for (const query of fallbackQueries) {
      if (songs.length >= limit) break;
      try {
        const extra = await searchSongs(query, limit - songs.length);
        const seen = new Set(songs.map((s) => s.videoId));
        songs.push(...extra.filter((s) => !seen.has(s.videoId)));
      } catch (error) {
        console.error('Trending fallback failed:', error.message);
      }
    }
  }

  if (!songs.length) throw new Error('Failed to load trending songs');

  await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
  return songs.slice(0, limit);
};

const getRecommendations = async (videoId, limit = 10) => {
  const cacheKey = `recommendations:${videoId}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  try {
    const song = await getSongById(videoId);
    if (!song) return [];

    const searchQuery = `${song.title} ${song.artist}`;
    const results = await searchSongs(searchQuery, limit + 5);
    const recommendations = results
      .filter((s) => s.videoId !== videoId)
      .slice(0, limit);

    await cacheSet(cacheKey, recommendations, CACHE_TTL.RECOMMENDATIONS);
    return recommendations;
  } catch (error) {
    console.error('yt-dlp recommendations error:', error.message);
    return [];
  }
};

const searchByGenre = async (genre, limit = 20) => {
  const cacheKey = `genre:${genre}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  try {
    const results = await searchSongs(`${genre} music`, limit);
    const genreSongs = results
      .filter((s) => {
        const haystack = `${s.title} ${s.artist} ${s.genre}`.toLowerCase();
        return haystack.includes(genre.toLowerCase());
      })
      .slice(0, limit);

    const final = genreSongs.length >= 3 ? genreSongs : results.slice(0, limit);
    await cacheSet(cacheKey, final, CACHE_TTL.SEARCH);
    return final;
  } catch (error) {
    console.error('yt-dlp genre search error:', error.message);
    throw new Error('Genre search failed');
  }
};

const formatFlatEntry = (entry) => {
  if (!entry || !entry.id) return null;

  const videoId = entry.id;
  return {
    videoId,
    title: entry.title || 'Untitled',
    artist: entry.channel || entry.uploader || entry.channel_id || 'Unknown Artist',
    album: '',
    duration: entry.duration || 0,
    thumbnailUrl: getThumbnail(entry, videoId),
    viewCount: entry.view_count || 0,
    channelId: entry.channel_id || '',
    genre: entry.categories?.[0] || '',
    language: 'en',
    explicit: false,
  };
};

const formatVideoDetail = (video) => {
  if (!video) return null;

  const videoId = video.id;
  return {
    videoId,
    title: video.title || 'Untitled',
    artist: video.channel || video.uploader || video.channel_id || 'Unknown Artist',
    album: video.album || '',
    duration: video.duration || 0,
    thumbnailUrl: getThumbnail(video, videoId),
    viewCount: video.view_count || 0,
    channelId: video.channel_id || '',
    genre: video.categories?.[0] || video.category || '',
    language: video.language || 'en',
    explicit: false,
  };
};

const getThumbnail = (item, videoId) => {
  const thumbs = item.thumbnails;
  if (Array.isArray(thumbs) && thumbs.length) {
    const last = thumbs[thumbs.length - 1];
    if (last && last.url) return last.url.replace(/^http:\/\//, 'https://');
  }
  if (item.thumbnail) return item.thumbnail;
  return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
};

module.exports = {
  searchSongs,
  getSongById,
  getTrendingSongs,
  getRecommendations,
  searchByGenre,
  runYtDlp,
  diagnose,
  YTDLP_BIN,
};