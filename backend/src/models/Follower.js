const mongoose = require('mongoose');

const followerSchema = new mongoose.Schema({
  followerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  followingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
}, {
  timestamps: { createdAt: 'followedAt', updatedAt: false },
});

followerSchema.index({ followerId: 1, followingId: 1 }, { unique: true });

module.exports = mongoose.model('Follower', followerSchema);