const ytDlp = require('yt-dlp-exec');
const config = require('../config');
const { Song } = require('../models');
const { cacheGet, cacheSet } = require('../config/redis');

const AUDIO_CACHE_TTL = config.audio.cacheTtlHours * 60 * 60;

const extractAudioUrl = async (videoId) => {
  const cacheKey = `audio:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached.url;

  // MongoDB read is best-effort: if the DB is unavailable we still
  // want to serve audio straight from YouTube.
  let song = null;
  try {
    song = await Song.findOne({ videoId });
  } catch (dbError) {
    console.warn('MongoDB unavailable while reading audio cache:', dbError.message);
  }
  if (song && song.isAudioCacheValid()) {
    await cacheSet(cacheKey, { url: song.audioUrlCached }, AUDIO_CACHE_TTL);
    return song.audioUrlCached;
  }

  try {
    const url = `https://www.youtube.com/watch?v=${videoId}`;

    const result = await ytDlp(url, {
      dumpSingleJson: true,
      noWarnings: true,
      noCallHome: true,
      noCheckCertificate: true,
      preferFreeFormats: true,
      format: 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio',
    });

    const audioFormat = result.formats?.find(f => f.acodec !== 'none' && f.vcodec === 'none');
    if (!audioFormat || !audioFormat.url) {
      throw new Error('No audio format found');
    }

    const audioUrl = audioFormat.url;

    // Persisting to MongoDB is best-effort too - never fail playback
    // because the DB write failed.
    try {
      await Song.findOneAndUpdate(
        { videoId },
        { audioUrlCached: audioUrl, audioExtractedAt: new Date() },
        { upsert: true, new: true }
      );
    } catch (dbError) {
      console.warn('MongoDB unavailable while caching audio URL:', dbError.message);
    }

    await cacheSet(cacheKey, { url: audioUrl }, AUDIO_CACHE_TTL);
    return audioUrl;
  } catch (error) {
    console.error('Audio extraction error:', error);
    throw new Error('Failed to extract audio');
  }
};

const getCachedAudioUrl = async (videoId) => {
  const song = await Song.findOne({ videoId });
  if (song && song.isAudioCacheValid()) {
    return song.audioUrlCached;
  }
  return null;
};

const incrementAccessCount = async (videoId) => {
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
  getCachedAudioUrl,
  incrementAccessCount,
};