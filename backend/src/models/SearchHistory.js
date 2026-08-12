const mongoose = require('mongoose');

const searchHistorySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  query: {
    type: String,
    required: true,
    trim: true,
  },
}, {
  timestamps: { createdAt: 'searchedAt', updatedAt: false },
});

searchHistorySchema.index({ userId: 1, searchedAt: -1 });

module.exports = mongoose.model('SearchHistory', searchHistorySchema);