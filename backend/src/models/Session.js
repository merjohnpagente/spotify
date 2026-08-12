const mongoose = require('mongoose');

const sessionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  refreshToken: {
    type: String,
    required: true,
    index: true,
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 },
  },
}, {
  timestamps: { createdAt: 'createdAt', updatedAt: false },
});

sessionSchema.index({ userId: 1, refreshToken: 1 });

module.exports = mongoose.model('Session', sessionSchema);