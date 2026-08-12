const { Playlist, Song } = require('../models');
const { getOrCreateSong } = require('./songService');
const { deleteAvatar } = require('./imageService');
const { cacheGet, cacheSet, cacheDelete, cacheDeletePattern } = require('../config/redis');

const createPlaylist = async (userId, { title, description, isPublic }) => {
  const playlist = await Playlist.create({
    userId,
    title,
    description: description || '',
    isPublic: isPublic !== false,
    songIds: [],
    totalDuration: 0,
  });
  await cacheDeletePattern(`user:${userId}:playlists*`);
  return playlist.toPublicJSON();
};

const getPlaylistById = async (playlistId, userId = null) => {
  const cacheKey = `playlist:${playlistId}`;
  const cached = await cacheGet(cacheKey);
  if (cached) {
    if (!cached.isPublic && cached.userId.toString() !== userId) {
      throw new Error('Playlist not found');
    }
    return cached;
  }

  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (!playlist.isPublic && playlist.userId.toString() !== userId) {
    throw new Error('Playlist not found');
  }

  const songs = [];
  for (const videoId of playlist.songIds) {
    const song = await getOrCreateSong(videoId);
    songs.push(song.toPublicJSON());
  }

  const result = { ...playlist.toPublicJSON(), songs };
  await cacheSet(cacheKey, result, 5 * 60);
  return result;
};

const updatePlaylist = async (playlistId, userId, updates) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (playlist.userId.toString() !== userId) throw new Error('Not authorized');

  const allowed = ['title', 'description', 'isPublic', 'coverImageUrl'];
  for (const key of allowed) {
    if (updates[key] !== undefined) playlist[key] = updates[key];
  }

  await playlist.save();
  await cacheDelete(`playlist:${playlistId}`);
  await cacheDeletePattern(`user:${userId}:playlists*`);
  return playlist.toPublicJSON();
};

const deletePlaylist = async (playlistId, userId) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (playlist.userId.toString() !== userId) throw new Error('Not authorized');

  if (playlist.coverImageUrl) {
    const publicId = playlist.coverImageUrl.split('/').pop()?.split('.')[0];
    if (publicId) await deleteAvatar(`spotify-clone/playlists/${publicId}`);
  }

  await Playlist.findByIdAndDelete(playlistId);
  await cacheDelete(`playlist:${playlistId}`);
  await cacheDeletePattern(`user:${userId}:playlists*`);
};

const addSongToPlaylist = async (playlistId, userId, videoId) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (playlist.userId.toString() !== userId) throw new Error('Not authorized');

  if (playlist.songIds.includes(videoId)) throw new Error('Song already in playlist');

  const song = await getOrCreateSong(videoId);
  playlist.songIds.push(videoId);
  playlist.totalDuration += song.duration;
  await playlist.save();

  await cacheDelete(`playlist:${playlistId}`);
  await cacheDeletePattern(`user:${userId}:playlists*`);
  return playlist.toPublicJSON();
};

const removeSongFromPlaylist = async (playlistId, userId, videoId) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (playlist.userId.toString() !== userId) throw new Error('Not authorized');

  const index = playlist.songIds.indexOf(videoId);
  if (index === -1) throw new Error('Song not in playlist');

  const song = await Song.findOne({ videoId });
  if (song) playlist.totalDuration = Math.max(0, playlist.totalDuration - song.duration);
  playlist.songIds.splice(index, 1);
  await playlist.save();

  await cacheDelete(`playlist:${playlistId}`);
  await cacheDeletePattern(`user:${userId}:playlists*`);
  return playlist.toPublicJSON();
};

const getUserPlaylists = async (userId, limit = 20) => {
  const cacheKey = `user:${userId}:playlists:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const playlists = await Playlist.find({ userId, isPublic: true })
    .sort({ createdAt: -1 })
    .limit(limit);

  const result = playlists.map(p => p.toPublicJSON());
  await cacheSet(cacheKey, result, 5 * 60);
  return result;
};

const getPlaylistSongs = async (playlistId) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');

  const songs = [];
  for (const videoId of playlist.songIds) {
    const song = await getOrCreateSong(videoId);
    songs.push(song.toPublicJSON());
  }
  return songs;
};

const reorderPlaylistSongs = async (playlistId, userId, songIds) => {
  const playlist = await Playlist.findById(playlistId);
  if (!playlist) throw new Error('Playlist not found');
  if (playlist.userId.toString() !== userId) throw new Error('Not authorized');

  playlist.songIds = songIds;
  let totalDuration = 0;
  for (const videoId of songIds) {
    const song = await Song.findOne({ videoId });
    if (song) totalDuration += song.duration;
  }
  playlist.totalDuration = totalDuration;
  await playlist.save();

  await cacheDelete(`playlist:${playlistId}`);
  await cacheDeletePattern(`user:${userId}:playlists*`);
  return playlist.toPublicJSON();
};

module.exports = {
  createPlaylist,
  getPlaylistById,
  updatePlaylist,
  deletePlaylist,
  addSongToPlaylist,
  removeSongFromPlaylist,
  getUserPlaylists,
  getPlaylistSongs,
  reorderPlaylistSongs,
};