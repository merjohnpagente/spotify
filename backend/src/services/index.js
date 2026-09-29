const authService = require('./authService');
const youtubeService = require('./youtubeService');
const audioService = require('./audioService');
const emailService = require('./emailService');
const imageService = require('./imageService');
const songService = require('./songService');
const playlistService = require('./playlistService');
const userService = require('./userService');

module.exports = {
  auth: authService,
  youtube: youtubeService,
  audio: audioService,
  email: emailService,
  image: imageService,
  song: songService,
  playlist: playlistService,
  user: userService,
};