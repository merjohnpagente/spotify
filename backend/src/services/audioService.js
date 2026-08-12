const ytDlp = require('yt-dlp-exec');
const config = require('../config');
const { Song } = require('../models');
const { cacheGet, cacheSet } = require('../config/redis');

const AUDIO_CACHE_TTL = config.audio.cacheTtlHours * 60 * 60;

const extractAudioUrl = async (videoId) => {
  const cacheKey = `audio:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached.url;

  const song = await Song.findOne({ videoId });
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

    await Song.findOneAndUpdate(
      { videoId },
      { audioUrlCached: audioUrl, audioExtractedAt: new Date() },
      { upsert: true, new: true }
    );

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
  await Song.findOneAndUpdate(
    { videoId },
    { $inc: { accessCount: 1 } }
  );
};

module.exports = {
  extractAudioUrl,
  getCachedAudioUrl,
  incrementAccessCount,
};