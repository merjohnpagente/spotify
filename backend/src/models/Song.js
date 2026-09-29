const mongoose = require('mongoose');
const config = require('../config');

const songSchema = new mongoose.Schema({
  videoId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  artist: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  album: {
    type: String,
    trim: true,
    default: '',
  },
  duration: {
    type: Number,
    required: false,
    default: 0,
  },
  thumbnailUrl: {
    type: String,
    required: true,
  },
  viewCount: {
    type: Number,
    default: 0,
  },
  channelId: {
    type: String,
    required: false,
    default: 'unknown',
  },
  genre: {
    type: String,
    trim: true,
    index: true,
  },
  language: {
    type: String,
    trim: true,
    default: 'en',
  },
  explicit: {
    type: Boolean,
    default: false,
  },
  source: {
    type: String,
    default: 'youtube',
  },
  isPreview: {
    type: Boolean,
    default: false,
  },
  audioUrlCached: {
    type: String,
    default: null,
  },
  audioExtractedAt: {
    type: Date,
    default: null,
  },
  isAvailable: {
    type: Boolean,
    default: true,
  },
  accessCount: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: { createdAt: 'addedToSystemAt', updatedAt: false },
});

songSchema.index({ title: 'text', artist: 'text', album: 'text' });

songSchema.methods.isAudioCacheValid = function() {
  if (!this.audioUrlCached || !this.audioExtractedAt) return false;
  const cacheAgeHours = (Date.now() - this.audioExtractedAt.getTime()) / (1000 * 60 * 60);
  // Configurable TTL (default 5h) < googlevideo 6h signed-URL expiry.
  return cacheAgeHours < config.audio.cacheTtlHours;
};

songSchema.methods.toPublicJSON = function() {
  return {
    id: this._id,
    videoId: this.videoId,
    title: this.title,
    artist: this.artist,
    album: this.album,
    duration: this.duration,
    thumbnailUrl: this.thumbnailUrl,
    viewCount: this.viewCount,
    channelId: this.channelId,
    genre: this.genre,
    language: this.language,
    explicit: this.explicit,
    isAvailable: this.isAvailable,
    addedToSystemAt: this.addedToSystemAt,
    source: this.source || (this.videoId && this.videoId.startsWith('dz_') ? 'deezer' : this.videoId && this.videoId.startsWith('au_') ? 'audius' : this.videoId && this.videoId.startsWith('jm_') ? 'jamendo' : 'youtube'),
    isPreview: this.isPreview || (this.videoId && this.videoId.startsWith('dz_')),
  };
};

module.exports = mongoose.model('Song', songSchema);