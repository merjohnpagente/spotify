const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
    index: true,
  },
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 3,
    maxlength: 30,
    index: true,
  },
  passwordHash: {
    type: String,
    required: true,
    select: false,
  },
  firstName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },
  lastName: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },
  avatarUrl: {
    type: String,
    default: null,
  },
  bio: {
    type: String,
    maxlength: 500,
    default: '',
  },
  accountStatus: {
    type: String,
    enum: ['active', 'suspended', 'deleted'],
    default: 'active',
  },
  preferences: {
    theme: {
      type: String,
      enum: ['dark', 'light', 'system'],
      default: 'dark',
    },
    audioQuality: {
      type: String,
      enum: ['low', 'medium', 'high'],
      default: 'medium',
    },
    language: {
      type: String,
      default: 'en',
    },
    notifications: {
      type: Boolean,
      default: true,
    },
  },
  stats: {
    totalListeningTime: {
      type: Number,
      default: 0,
    },
    totalSongsPlayed: {
      type: Number,
      default: 0,
    },
    likedSongsCount: {
      type: Number,
      default: 0,
    },
  },
  lastLoginAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

userSchema.pre('save', async function(next) {
  if (!this.isModified('passwordHash')) return next();
  this.passwordHash = await bcrypt.hash(this.passwordHash, 10);
  next();
});

userSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.passwordHash);
};

userSchema.methods.toPublicJSON = function() {
  return {
    id: this._id,
    email: this.email,
    username: this.username,
    firstName: this.firstName,
    lastName: this.lastName,
    avatarUrl: this.avatarUrl,
    bio: this.bio,
    preferences: this.preferences,
    stats: this.stats,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

module.exports = mongoose.model('User', userSchema);