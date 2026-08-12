const cloudinary = require('cloudinary').v2;
const config = require('./index');

const configureCloudinary = () => {
  if (!config.cloudinary.cloudName || !config.cloudinary.apiKey || !config.cloudinary.apiSecret) {
    console.warn('Cloudinary credentials not configured');
    return false;
  }

  cloudinary.config({
    cloud_name: config.cloudinary.cloudName,
    api_key: config.cloudinary.apiKey,
    api_secret: config.cloudinary.apiSecret,
    secure: true,
  });

  console.log('Cloudinary configured');
  return true;
};

const uploadImage = async (fileBuffer, folder = 'spotify-clone', options = {}) => {
  return new Promise((resolve, reject) => {
    const uploadOptions = {
      folder,
      resource_type: 'image',
      transformation: [
        { width: 800, height: 800, crop: 'limit', quality: 'auto' },
        { format: 'webp' },
      ],
      ...options,
    };

    cloudinary.uploader.upload_stream(uploadOptions, (error, result) => {
      if (error) reject(error);
      else resolve(result);
    }).end(fileBuffer);
  });
};

const deleteImage = async (publicId) => {
  try {
    const result = await cloudinary.uploader.destroy(publicId);
    return result;
  } catch (error) {
    console.error('Cloudinary delete error:', error);
    throw error;
  }
};

const getOptimizedUrl = (publicId, options = {}) => {
  return cloudinary.url(publicId, {
    secure: true,
    quality: 'auto',
    fetch_format: 'auto',
    ...options,
  });
};

module.exports = {
  configureCloudinary,
  uploadImage,
  deleteImage,
  getOptimizedUrl,
  cloudinary,
};