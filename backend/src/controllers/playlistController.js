const { playlist } = require('../services');
const catchAsync = require('../utils/catchAsync');

const create = catchAsync(async (req, res) => {
  const { title, description, isPublic } = req.body;
  const result = await playlist.createPlaylist(req.userId, { title, description, isPublic });
  res.status(201).json(result);
});

const getById = catchAsync(async (req, res) => {
  const result = await playlist.getPlaylistById(req.params.playlistId, req.userId || null);
  res.json(result);
});

const update = catchAsync(async (req, res) => {
  const result = await playlist.updatePlaylist(req.params.playlistId, req.userId, req.body);
  res.json(result);
});

const remove = catchAsync(async (req, res) => {
  await playlist.deletePlaylist(req.params.playlistId, req.userId);
  res.json({ message: 'Playlist deleted' });
});

const addSong = catchAsync(async (req, res) => {
  const result = await playlist.addSongToPlaylist(req.params.playlistId, req.userId, req.body.videoId);
  res.status(201).json(result);
});

const removeSong = catchAsync(async (req, res) => {
  const result = await playlist.removeSongFromPlaylist(req.params.playlistId, req.userId, req.params.videoId);
  res.json(result);
});

const getMyPlaylists = catchAsync(async (req, res) => {
  const limit = parseInt(req.query.limit) || 20;
  const result = await playlist.getUserPlaylists(req.userId, limit);
  res.json({ results: result });
});

const getPlaylistSongs = catchAsync(async (req, res) => {
  const songs = await playlist.getPlaylistSongs(req.params.playlistId);
  res.json({ results: songs });
});

const reorder = catchAsync(async (req, res) => {
  const result = await playlist.reorderPlaylistSongs(req.params.playlistId, req.userId, req.body.songIds);
  res.json(result);
});

module.exports = {
  create,
  getById,
  update,
  remove,
  addSong,
  removeSong,
  getMyPlaylists,
  getPlaylistSongs,
  reorder,
};