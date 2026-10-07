const mongoose = require('mongoose');

// Single-use password-reset tokens. Only the SHA-256 hash is stored —
// a database leak alone never yields a usable reset link.
const passwordResetTokenSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  tokenHash: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 },
  },
  used: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: { createdAt: 'createdAt', updatedAt: false },
});

module.exports = mongoose.model('PasswordResetToken', passwordResetTokenSchema);
