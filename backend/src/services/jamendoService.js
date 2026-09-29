const config = require('../config');
const { cacheGet, cacheSet } = require('../config/redis');

// Jamendo — free, legal Creative-Commons music API (publicapis.io/jamendo-api).
// Direct mp3 stream URLs, no bot-checks, no preview limits — full tracks.
// Auth: client_id from https://devportal.jamendo.com (free registration).
// Without JAMENDO_CLIENT_ID every call degrades to empty/null instantly,
// same pattern as optional Mailgun/Cloudinary config.
const BASE = 'https://api.jamendo.com/v3.0';

const CACHE_TTL = {
  SEARCH: 6 * 60 * 60,
  TRENDING: 60 * 60,
};

const clientId = () => (config.jamendo && config.jamendo.clientId) || '';

const mapJamendoTrack = (t) => {
  if (!t || !t.id) return null;
  const id = String(t.id);
  return {
    videoId: `jm_${id}`, // prefix to avoid collision with YouTube 11-char / dz_ / au_
    title: t.name || 'Untitled',
    artist: t.artist_name || 'Unknown Artist',
    album: t.album_name || '',
    duration: Number(t.duration) || 0,
    thumbnailUrl:
      t.album_image ||
      t.image ||
      (t.album_id ? `https://usercontent1.jamendo.com/?type=album&id=${t.album_id}&width=300` : null),
    viewCount: Number(t.popularity) || 0,
    channelId: String(t.artist_id || 'unknown'),
    genre: (t.musicinfo && t.musicinfo.tags && t.musicinfo.tags.genres && t.musicinfo.tags.genres[0]) || '',
    language: 'en',
    explicit: false,
    source: 'jamendo',
    isPreview: false, // full track, not a 30s preview
    audioUrl: t.audio || t.audiodownload || null, // direct mp3 stream
  };
};

// GET helper: hits Jamendo with client_id + 8s abort, returns parsed json.
const jamendoGet = async (path, params = {}) => {
  const cid = clientId();
  if (!cid) return null;
  const qs = new URLSearchParams({ client_id: cid, format: 'json', ...params });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const resp = await fetch(`${BASE}/${path}?${qs}`, { signal: controller.signal });
    if (!resp.ok) throw new Error(`Jamendo ${resp.status}`);
    const data = await resp.json();
    if (data.headers && data.headers.code && data.headers.code !== 0) {
      throw new Error(data.headers.error_message || `Jamendo error ${data.headers.code}`);
    }
    return data;
  } finally {
    clearTimeout(timer);
  }
};

const searchSongs = async (query, limit = 20) => {
  if (!clientId()) return [];
  const cacheKey = `jm:search:${query}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const data = await jamendoGet('tracks', {
      names: query,
      limit: String(limit),
      order: 'popularity_month',
    });
    const songs = ((data && data.results) || []).map(mapJamendoTrack).filter(Boolean).slice(0, limit);
    if (songs.length) await cacheSet(cacheKey, songs, CACHE_TTL.SEARCH);
    return songs;
  } catch (e) {
    console.warn(`Jamendo search failed for "${query}": ${e.message}`);
    return [];
  }
};

const getSongById = async (videoId) => {
  if (!clientId()) return null;
  const rawId = videoId.startsWith('jm_') ? videoId.slice(3) : videoId;
  if (!/^\d+$/.test(rawId)) return null;
  const cacheKey = `jm:track:${rawId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const data = await jamendoGet('tracks', { id: rawId });
    const song = mapJamendoTrack(data && data.results && data.results[0]);
    if (song) await cacheSet(cacheKey, song, CACHE_TTL.SEARCH);
    return song;
  } catch (_) {
    return null;
  }
};

const getTrendingSongs = async (limit = 20) => {
  if (!clientId()) return [];
  const cacheKey = `jm:trending:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;
  try {
    const data = await jamendoGet('tracks', {
      order: 'popularity_month',
      limit: String(limit),
    });
    const songs = ((data && data.results) || []).map(mapJamendoTrack).filter(Boolean).slice(0, limit);
    if (songs.length) await cacheSet(cacheKey, songs, CACHE_TTL.TRENDING);
    return songs;
  } catch (e) {
    console.warn(`Jamendo trending failed: ${e.message}`);
    return [];
  }
};

// Full-track mp3 stream URL (no key needed beyond client_id already in call).
const getStreamUrl = async (videoId) => {
  const song = await getSongById(videoId);
  return song ? song.audioUrl || null : null;
};

module.exports = { searchSongs, getSongById, getTrendingSongs, getStreamUrl, mapJamendoTrack };
