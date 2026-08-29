const { cacheGet, cacheSet } = require('../config/redis');

const CACHE_TTL = {
  SEARCH: 6 * 60 * 60,
  TRENDING: 60 * 60,
};

const mapDeezerTrack = (t) => {
  if (!t || !t.id) return null;
  const id = String(t.id);
  return {
    videoId: `dz_${id}`, // prefix to avoid collision with YouTube 11-char
    title: t.title || 'Untitled',
    artist: (t.artist && t.artist.name) || 'Unknown Artist',
    album: (t.album && t.album.title) || '',
    duration: Number(t.duration) || 0,
    thumbnailUrl: (t.album && (t.album.cover_big || t.album.cover_medium)) || `https://api.deezer.com/album/${t.album?.id}/image`,
    viewCount: Number(t.rank) || 0,
    channelId: String((t.artist && t.artist.id) || 'unknown'),
    genre: '',
    language: 'en',
    explicit: Boolean(t.explicit_lyrics),
    source: 'deezer',
    previewUrl: t.preview || null, // 30s mp3, CORS allowed
  };
};

const searchSongs = async (query, limit = 20) => {
  const cacheKey = `dz:search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    const resp = await fetch(`https://api.deezer.com/search?q=${encodeURIComponent(query)}&limit=${limit}`, { signal: controller.signal });
    clearTimeout(t);
    if (!resp.ok) throw new Error(`Deezer ${resp.status}`);
    const data = await resp.json();
    const tracks = Array.isArray(data.data) ? data.data : [];
    const songs = tracks.map(mapDeezerTrack).filter(Boolean).slice(0, limit);
    await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
    return songs;
  } catch (e) {
    console.warn(`Deezer search failed for "${query}": ${e.message}`);
    return [];
  }
};

const getSongById = async (videoId) => {
  const rawId = videoId.startsWith('dz_') ? videoId.slice(3) : videoId;
  if (!/^\d+$/.test(rawId)) return null;
  const cacheKey = `dz:track:${rawId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    const resp = await fetch(`https://api.deezer.com/track/${rawId}`, { signal: controller.signal });
    clearTimeout(t);
    if (!resp.ok) return null;
    const tdata = await resp.json();
    if (tdata.error) return null;
    const song = mapDeezerTrack(tdata);
    if (song) await cacheSet(cacheKey, song, CACHE_TTL.SEARCH);
    return song;
  } catch (_) {
    return null;
  }
};

const getTrendingSongs = async (limit = 20) => {
  const cacheKey = `dz:trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);
    const resp = await fetch(`https://api.deezer.com/chart/0/tracks?limit=${limit}`, { signal: controller.signal });
    clearTimeout(t);
    if (!resp.ok) throw new Error(`Deezer chart ${resp.status}`);
    const data = await resp.json();
    const tracks = data.data || data.tracks?.data || [];
    const songs = tracks.map(mapDeezerTrack).filter(Boolean).slice(0, limit);
    if (songs.length) {
      await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
      return songs;
    }
    return [];
  } catch (e) {
    console.warn(`Deezer trending failed: ${e.message}`);
    return [];
  }
};

const getPreviewUrl = async (videoId) => {
  const song = await getSongById(videoId);
  return song ? song.previewUrl : null;
};

module.exports = { searchSongs, getSongById, getTrendingSongs, getPreviewUrl, mapDeezerTrack };
