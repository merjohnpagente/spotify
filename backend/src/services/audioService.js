const mongoose = require('mongoose');
const config = require('../config');
const { Song } = require('../models');
const { cacheGet, cacheSet } = require('../config/redis');
const { runYtDlp } = require('./youtubeService');

const isDbReady = () => mongoose.connection.readyState === 1;

const AUDIO_CACHE_TTL = config.audio.cacheTtlHours * 60 * 60;

// YouTube blocks stream extraction differently per network: residential IPs
// work with the default web client, datacenter IPs (Render etc.) often need
// mobile clients. We probe strategies in order and REMEMBER the winner, so
// after the first successful play the fast path is used immediately.
// On Render (datacenter) android succeeds in ~6s while default fails after 25s — put android first.
const STRATEGIES = [
  { label: 'android', extractorArgs: 'youtube:player_client=android' },
  { label: 'ios', extractorArgs: 'youtube:player_client=ios' },
  { label: 'mweb', extractorArgs: 'youtube:player_client=mweb' },
  { label: 'default', extractorArgs: null },
  { label: 'tv_embedded', extractorArgs: 'youtube:player_client=tv_embedded' },
  { label: 'web_embedded', extractorArgs: 'youtube:player_client=web_embedded' },
];

let preferredStrategy = null;
const getPreferredStrategy = () => preferredStrategy;

const strategyOptions = (strategy) => {
  const options = {
    skipDownload: true,
    noPlaylist: true,
    format: 'bestaudio/best',
  };
  if (strategy && strategy.extractorArgs) options.extractorArgs = strategy.extractorArgs;
  return options;
};

const pickAudioUrl = (result) => {
  // yt-dlp puts the selected format's direct URL at the top level.
  if (result && result.url) return result.url;
  const formats = Array.isArray(result && result.formats) ? result.formats : [];
  const audioOnly = formats.filter(
    (f) => f && f.url && f.acodec !== 'none' && f.vcodec === 'none'
  );
  if (audioOnly.length) {
    // Pick the HIGHEST bitrate - yt-dlp lists formats roughly worst-first.
    audioOnly.sort((a, b) => (b.abr || b.tbr || 0) - (a.abr || a.tbr || 0));
    return audioOnly[0].url;
  }
  const any = formats.find((f) => f && f.url);
  return any ? any.url : null;
};

// Test ONE strategy in isolation (used by the debug probe and by the chain).
const extractWithStrategy = async (url, strategyLabel, timeoutMs = 15000) => {
  const strategy =
    STRATEGIES.find((s) => s.label === strategyLabel) || STRATEGIES[0];
  const result = await runYtDlp(url, strategyOptions(strategy), timeoutMs);
  const audioUrl = pickAudioUrl(result);
  if (!audioUrl) throw new Error('No audio URL in yt-dlp output');
  preferredStrategy = strategy.label;
  return audioUrl;
};

const extractWithFallbacks = async (url) => {
  // Hard deadline 60s so Render (30s proxy timeout is increased) + client 90s always wins.
  // With android first, most videos succeed in 5-10s, no 25s waste on failing default.
  const deadline = Date.now() + 60000;
  const order = preferredStrategy
    ? [
        ...STRATEGIES.filter((s) => s.label === preferredStrategy),
        ...STRATEGIES.filter((s) => s.label !== preferredStrategy),
      ]
    : STRATEGIES;

  let lastError = null;
  for (const strategy of order) {
    if (Date.now() > deadline - 15000) break;
    try {
      const audioUrl = await extractWithStrategy(url, strategy.label, 15000);
      return audioUrl;
    } catch (error) {
      lastError = error;
      console.warn(
        `stream strategy "${strategy.label}" failed: ${String(error.message).split('\n')[0]}`
      );
    }
  }
  throw lastError || new Error('Audio extraction failed');
};

const extractAudioUrl = async (videoId) => {
  const cacheKey = `audio:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached.url;

  // MongoDB read is best-effort: if the DB is unavailable we still
  // want to serve audio straight from YouTube.
  let song = null;
  if (isDbReady()) {
    try {
      song = await Song.findOne({ videoId });
    } catch (dbError) {
      console.warn('MongoDB unavailable while reading audio cache:', dbError.message);
    }
    if (song && song.isAudioCacheValid()) {
      await cacheSet(cacheKey, { url: song.audioUrlCached }, AUDIO_CACHE_TTL);
      return song.audioUrlCached;
    }
  }

  try {
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    const audioUrl = await extractWithFallbacks(url);

    // Persisting to MongoDB is best-effort too - never fail playback
    // because the DB write failed.
    if (isDbReady()) {
      try {
        await Song.findOneAndUpdate(
          { videoId },
          { audioUrlCached: audioUrl, audioExtractedAt: new Date() },
          { upsert: false }
        );
      } catch (dbError) {
        console.warn('MongoDB unavailable while caching audio URL:', dbError.message);
      }
    }

    await cacheSet(cacheKey, { url: audioUrl }, AUDIO_CACHE_TTL);
    return audioUrl;
  } catch (error) {
    console.error('Audio extraction error:', error.message);
    if (error.stderr) {
      console.error('yt-dlp stderr:', String(error.stderr).slice(0, 500));
    }
    throw new Error('Failed to extract audio');
  }
};

const getCachedAudioUrl = async (videoId) => {
  if (!isDbReady()) return null;
  const song = await Song.findOne({ videoId });
  if (song && song.isAudioCacheValid()) {
    return song.audioUrlCached;
  }
  return null;
};

const incrementAccessCount = async (videoId) => {
  if (!isDbReady()) return;
  try {
    await Song.findOneAndUpdate(
      { videoId },
      { $inc: { accessCount: 1 } }
    );
  } catch (dbError) {
    console.warn('MongoDB unavailable while counting access:', dbError.message);
  }
};

module.exports = {
  extractAudioUrl,
  extractWithFallbacks,
  extractWithStrategy,
  getPreferredStrategy,
  STRATEGIES,
  getCachedAudioUrl,
  incrementAccessCount,
};