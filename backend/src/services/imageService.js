const { uploadImage, deleteImage, getOptimizedUrl, configureCloudinary } = require('../config/cloudinary');

configureCloudinary();

const uploadAvatar = async (fileBuffer) => {
  return uploadImage(fileBuffer, 'spotify-clone/avatars', {
    transformation: [
      { width: 400, height: 400, crop: 'fill', gravity: 'face', quality: 'auto' },
      { format: 'webp' },
    ],
  });
};

const uploadPlaylistCover = async (fileBuffer) => {
  return uploadImage(fileBuffer, 'spotify-clone/playlists', {
    transformation: [
      { width: 800, height: 800, crop: 'fill', quality: 'auto' },
      { format: 'webp' },
    ],
  });
};

const deleteAvatar = async (publicId) => {
  return deleteImage(publicId);
};

const getAvatarUrl = (publicId, options = {}) => {
  return getOptimizedUrl(publicId, { width: 400, height: 400, crop: 'fill', gravity: 'face', ...options });
};

const getPlaylistCoverUrl = (publicId, options = {}) => {
  return getOptimizedUrl(publicId, { width: 800, height: 800, crop: 'fill', ...options });
};

module.exports = {
  uploadAvatar,
  uploadPlaylistCover,
  deleteAvatar,
  getAvatarUrl,
  getPlaylistCoverUrl,
};