const mongoose = require('mongoose');

const userHistorySchema = new mongoose.Schema({
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
  playDuration: {
    type: Number,
    default: 0,
  },
  completed: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: { createdAt: 'playedAt', updatedAt: false },
});

userHistorySchema.index({ userId: 1, playedAt: -1 });
userHistorySchema.index({ userId: 1, videoId: 1 });

module.exports = mongoose.model('UserHistory', userHistorySchema);