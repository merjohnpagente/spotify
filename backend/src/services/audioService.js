const mongoose = require('mongoose');
const config = require('../config');
const { Song } = require('../models');
const { cacheGet, cacheSet, cacheDelete } = require('../config/redis');
const { runYtDlp } = require('./youtubeService');
const audiusService = require('./audiusService');
const deezerService = require('./deezerService');

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

// Circuit breaker: after 2 consecutive full failed runs skip Invidious for
// 5 minutes — volunteer hosts that are down just add latency to every play.
let invidiousConsecutiveFails = 0;
let invidiousDownUntil = 0;
const INVIDIOUS_BREAKER_MS = 5 * 60 * 1000;

const getInvidiousCircuitState = () => ({
  open: Date.now() < invidiousDownUntil,
  consecutiveFails: invidiousConsecutiveFails,
});

const resetInvidiousCircuit = () => {
  invidiousConsecutiveFails = 0;
  invidiousDownUntil = 0;
};

const fetchViaInvidious = async (videoId) => {
  if (Date.now() < invidiousDownUntil) return null; // circuit open — fail fast
  // Sorted by uptime 2025-2026: inv.tux.pizza most stable, yewtu.be often 403
  const hosts = ['https://inv.tux.pizza', 'https://vid.puffyan.us', 'https://yewtu.be', 'https://invidious.snopyta.org', 'https://invidious.lunar.icu'];
  for (const host of hosts) {
    const controller = new AbortController();
    let t = null;
    try {
      t = setTimeout(() => controller.abort(), 5000);
      const resp = await fetch(`${host}/api/v1/videos/${videoId}`, { signal: controller.signal });
      if (!resp.ok) continue;
      const data = await resp.json();
      const adaptive = data.adaptiveFormats || [];
      const audio = adaptive.filter((f) => f.type && f.type.includes('audio') && f.url);
      const pick = audio.length ? audio : adaptive;
      if (!pick.length) continue;
      pick.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
      if (pick[0].url) {
        invidiousConsecutiveFails = 0; // success resets the breaker
        return pick[0].url;
      }
    } catch (_) {
      continue;
    } finally {
      if (t) clearTimeout(t);
    }
  }
  // Whole run failed (all hosts down/errors).
  invidiousConsecutiveFails += 1;
  if (invidiousConsecutiveFails >= 2) {
    invidiousDownUntil = Date.now() + INVIDIOUS_BREAKER_MS;
    console.warn('invidious circuit opened after 2 consecutive failed runs, skipping for 5 min');
  }
  return null;
};

const extractAudioUrl = async (videoId) => {
  const cacheKey = `audio:${videoId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached.url;

  // Fast path: Audius (no bot block, <2s) and Deezer preview (30s) before YouTube
  if (videoId.startsWith('au_')) {
    const auUrl = await audiusService.getStreamUrl(videoId);
    if (auUrl) {
      await cacheSet(cacheKey, { url: auUrl }, AUDIO_CACHE_TTL);
      return auUrl;
    }
  }
  if (videoId.startsWith('dz_')) {
    // Fast parallel: Audius full-track race vs 30s preview — don't block preview >2.5s
    const previewPromise = deezerService.getPreviewUrl(videoId).catch(() => null);
    const audiusPromise = (async () => {
      try {
        const dzSong = await Promise.race([
          deezerService.getSongById(videoId),
          new Promise((_, rej) => setTimeout(() => rej(new Error('dz timeout')), 2500)),
        ]);
        if (!dzSong) return null;
        const auSearch = await Promise.race([
          audiusService.searchSongs(`${dzSong.title} ${dzSong.artist}`, 3),
          new Promise((_, rej) => setTimeout(() => rej(new Error('au search timeout')), 2500)),
        ]);
        if (!auSearch || !auSearch.length) return null;
        const auUrl = await Promise.race([
          audiusService.getStreamUrl(auSearch[0].videoId),
          new Promise((_, rej) => setTimeout(() => rej(new Error('au stream timeout')), 2500)),
        ]);
        return auUrl || null;
      } catch (_) { return null; }
    })();
    const auUrl = await audiusPromise;
    if (auUrl) {
      await cacheSet(cacheKey, { url: auUrl }, AUDIO_CACHE_TTL);
      return auUrl;
    }
    const dzUrl = await previewPromise;
    if (dzUrl) {
      await cacheSet(cacheKey, { url: dzUrl }, AUDIO_CACHE_TTL);
      return dzUrl;
    }
  }

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
    // YouTube fallback: race Audius search for title vs yt-dlp (keeps old behavior for yt IDs)
    // For dz/au we already returned, so this is YouTube 11-char path
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    // Try Audius search by videoId text as last fast attempt before slow yt-dlp
    let audioUrl = null;
    // For dz/au we already returned, so only yt path races Invidious+yt-dlp
    try {
      audioUrl = await Promise.any([
        fetchViaInvidious(videoId).then((u) => { if (!u) throw new Error('invidious empty'); return u; }),
        extractWithFallbacks(url),
      ]);
    } catch {
      audioUrl = await fetchViaInvidious(videoId);
      if (!audioUrl) {
        audioUrl = await extractWithFallbacks(url);
      } else if (audioUrl.includes('googlevideo.com')) {
        // Remember invidious as winner only for direct googlevideo URLs —
        // volunteer proxy URLs are transient and shouldn't steer strategy.
        preferredStrategy = 'invidious';
      }
    }
    if (!audioUrl) throw new Error('No audio URL from any source');

    // DoD#4: never persist non-googlevideo (Invidious/proxy) URLs — they
    // 410 quickly and would poison both Mongo and Redis with dead links.
    // googlevideo signed URLs are safe for the 5h TTL (below 6h expiry).
    const isDirectGoogleVideo = audioUrl.includes('googlevideo.com');

    // Persisting to MongoDB is best-effort too - never fail playback
    // because the DB write failed.
    if (isDirectGoogleVideo && isDbReady()) {
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

    if (isDirectGoogleVideo) {
      await cacheSet(cacheKey, { url: audioUrl }, AUDIO_CACHE_TTL);
    }
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

// DoD#4: called by the audio proxy on upstream 403/410 (expired signed URL)
// so the next getSongStreamUrl re-extracts fresh instead of serving dead cache.
const clearAudioCache = async (videoId) => {
  try {
    await cacheDelete(`audio:${videoId}`);
  } catch (cacheError) {
    console.warn('Failed to clear redis audio cache:', cacheError.message);
  }
  if (isDbReady()) {
    try {
      await Song.findOneAndUpdate(
        { videoId },
        { audioUrlCached: null, audioExtractedAt: null }
      );
    } catch (dbError) {
      console.warn('MongoDB unavailable while clearing audio cache:', dbError.message);
    }
  }
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
  clearAudioCache,
  fetchViaInvidious,
  getInvidiousCircuitState,
  resetInvidiousCircuit,
};