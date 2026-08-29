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

const audioProxy = catchAsync(async (req, res) => {
  const { videoId } = req.params;
  const quality = req.query.quality || 'medium';
  const streamUrl = await song.getSongStreamUrl(videoId, quality);

  // If client explicitly wants redirect, just redirect (useful for native players)
  if (req.query.redirect === 'true') {
    return res.redirect(streamUrl);
  }

  const parsed = new URL(streamUrl);
  const isHttps = parsed.protocol === 'https:';
  const lib = isHttps ? require('node:https') : require('node:http');

  const options = {
    method: 'GET',
    headers: {},
  };
  if (req.headers.range) {
    options.headers.Range = req.headers.range;
  }
  // Forward minimal headers that YouTube expects
  options.headers['User-Agent'] =
    req.headers['user-agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  if (req.headers.referer) options.headers.Referer = req.headers.referer;

  const proxyReq = lib.request(parsed, options, (proxyRes) => {
    // Pass through relevant headers
    const headersToForward = [
      'content-type',
      'content-length',
      'content-range',
      'accept-ranges',
      'cache-control',
      'expires',
      'last-modified',
    ];
    for (const [key, value] of Object.entries(proxyRes.headers)) {
      if (headersToForward.includes(key.toLowerCase())) {
        res.setHeader(key, value);
      }
    }
    // Ensure CORS for web audio
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges, Content-Type');
    res.setHeader('Access-Control-Allow-Headers', 'Range');
    res.status(proxyRes.statusCode || 200);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('Audio proxy error:', err.message);
    if (!res.headersSent) {
      res.status(502).json({ error: 'Failed to proxy audio' });
    } else {
      res.end();
    }
  });

  // Client disconnected -> abort upstream
  req.on('close', () => {
    try {
      proxyReq.destroy();
    } catch (_) {
      // ignore destroy error
    }
  });

  proxyReq.end();
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
  audioProxy,
  recommendations,
  like,
  unlike,
  getLikedSongs,
  addHistory,
  getHistory,
  clearHistory,
  getStats,
};