const { cacheGet, cacheSet } = require('../config/redis');

const APP_NAME = 'SPOTIFY_FY';
const CACHE_TTL = {
  SEARCH: 6 * 60 * 60,
  TRENDING: 60 * 60,
};

// Audius discovery — api.audius.co returns a host, but we can hit the gateway directly
const AUDIUS_BASE = 'https://api.audius.co/v1';

const mapAudiusTrack = (t) => {
  if (!t || !t.id) return null;
  const id = String(t.id);
  return {
    videoId: `au_${id}`,
    title: t.title || 'Untitled',
    artist: (t.user && t.user.name) || 'Unknown Artist',
    album: t.album || '',
    duration: Number(t.duration) || 0,
    thumbnailUrl: t.artwork?.['1000x1000'] || t.artwork?.['480x480'] || t.artwork?.['150x150'] || `https://audius.co/api/v1/tracks/${id}/artwork?app_name=${APP_NAME}`,
    viewCount: Number(t.play_count) || 0,
    channelId: String((t.user && t.user.id) || 'unknown'),
    genre: t.genre || '',
    language: 'en',
    explicit: false,
    source: 'audius',
  };
};

const searchSongs = async (query, limit = 20) => {
  const cacheKey = `au:search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    const url = `${AUDIUS_BASE}/tracks/search?query=${encodeURIComponent(query)}&app_name=${APP_NAME}&limit=${limit}`;
    const resp = await fetch(url, { signal: controller.signal });
    clearTimeout(t);
    if (!resp.ok) throw new Error(`Audius ${resp.status}`);
    const data = await resp.json();
    const tracks = Array.isArray(data.data) ? data.data : [];
    const songs = tracks.map(mapAudiusTrack).filter(Boolean).slice(0, limit);
    await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
    return songs;
  } catch (e) {
    console.warn(`Audius search failed for "${query}": ${e.message}`);
    return [];
  }
};

const getTrendingSongs = async (limit = 20) => {
  const cacheKey = `au:trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    const url = `${AUDIUS_BASE}/tracks/trending?app_name=${APP_NAME}&limit=${limit}&timeRange=week`;
    const resp = await fetch(url, { signal: controller.signal });
    clearTimeout(t);
    if (!resp.ok) throw new Error(`Audius ${resp.status}`);
    const data = await resp.json();
    const tracks = Array.isArray(data.data) ? data.data : [];
    const songs = tracks.map(mapAudiusTrack).filter(Boolean).slice(0, limit);
    if (songs.length) {
      await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
      return songs;
    }
    return [];
  } catch (e) {
    console.warn(`Audius trending failed: ${e.message}`);
    return [];
  }
};

const getStreamUrl = async (videoId) => {
  const rawId = videoId.startsWith('au_') ? videoId.slice(3) : videoId;
  if (!rawId) return null;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    // Audius stream endpoint redirects to signed URL — we fetch with redirect manual to capture Location
    const url = `${AUDIUS_BASE}/tracks/${rawId}/stream?app_name=${APP_NAME}`;
    const resp = await fetch(url, { signal: controller.signal, redirect: 'manual' });
    clearTimeout(t);
    if (resp.status === 302 || resp.status === 301) {
      const loc = resp.headers.get('location');
      if (loc) return loc;
    }
    // Some gateways return 200 with stream directly or JSON with url
    if (resp.ok) {
      const text = await resp.text();
      if (text.startsWith('http')) return text.trim();
      try {
        const j = JSON.parse(text);
        if (j.data?.url) return j.data.url;
      } catch { /* ignore */ }
      // Fallback: try to return the URL itself (audius will redirect on play)
      return url;
    }
    return null;
  } catch (_) {
    return null;
  }
};

module.exports = { searchSongs, getTrendingSongs, getStreamUrl, mapAudiusTrack };
