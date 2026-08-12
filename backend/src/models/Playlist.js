const mongoose = require('mongoose');

const playlistSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100,
    index: true,
  },
  description: {
    type: String,
    trim: true,
    maxlength: 500,
    default: '',
  },
  coverImageUrl: {
    type: String,
    default: null,
  },
  songIds: [{
    type: String,
    trim: true,
  }],
  totalDuration: {
    type: Number,
    default: 0,
  },
  isPublic: {
    type: Boolean,
    default: true,
  },
  followerCount: {
    type: Number,
    default: 0,
  },
  playCount: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

playlistSchema.index({ userId: 1, createdAt: -1 });

playlistSchema.methods.toPublicJSON = function() {
  return {
    id: this._id,
    userId: this.userId,
    title: this.title,
    description: this.description,
    coverImageUrl: this.coverImageUrl,
    songIds: this.songIds,
    totalDuration: this.totalDuration,
    isPublic: this.isPublic,
    followerCount: this.followerCount,
    playCount: this.playCount,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('Playlist', playlistSchema);