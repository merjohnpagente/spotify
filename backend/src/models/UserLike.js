const mongoose = require('mongoose');

const userLikeSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  videoId: {
    type: String,
    required: true,
    index: true,
  },
}, {
  timestamps: { createdAt: 'likedAt', updatedAt: false },
});

userLikeSchema.index({ userId: 1, videoId: 1 }, { unique: true });

module.exports = mongoose.model('UserLike', userLikeSchema);