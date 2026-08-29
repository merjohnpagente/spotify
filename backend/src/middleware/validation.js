const { body, param, query, validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

const registerValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  body('username').isLength({ min: 3, max: 30 }).matches(/^[a-zA-Z0-9_]+$/).withMessage('Username must be 3-30 chars, alphanumeric and underscore only'),
  body('firstName').trim().isLength({ min: 1, max: 50 }).withMessage('First name required'),
  body('lastName').trim().isLength({ min: 1, max: 50 }).withMessage('Last name required'),
  validate,
];

const loginValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').notEmpty().withMessage('Password required'),
  validate,
];

const refreshTokenValidation = [
  body('refreshToken').notEmpty().withMessage('Refresh token required'),
  validate,
];

const googleAuthValidation = [
  body('idToken').notEmpty().withMessage('ID token required'),
  validate,
];

const forgotPasswordValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  validate,
];

const playlistValidation = [
  body('title').trim().isLength({ min: 1, max: 100 }).withMessage('Title required (1-100 chars)'),
  body('description').optional().trim().isLength({ max: 500 }).withMessage('Description max 500 chars'),
  body('isPublic').optional().isBoolean().withMessage('isPublic must be boolean'),
  validate,
];

const addSongValidation = [
  body('videoId').matches(/^(?:[a-zA-Z0-9_-]{11}|(?:dz|au)_[a-zA-Z0-9_-]+)$/).withMessage('Valid video/track ID required'),
  validate,
];

const updatePlaylistValidation = [
  body('title').optional().trim().isLength({ min: 1, max: 100 }).withMessage('Title 1-100 chars'),
  body('description').optional().trim().isLength({ max: 500 }).withMessage('Description max 500 chars'),
  body('isPublic').optional().isBoolean().withMessage('isPublic must be boolean'),
  body('coverImageUrl').optional().isURL().withMessage('Invalid cover image URL'),
  validate,
];

const reorderValidation = [
  body('songIds').isArray().withMessage('songIds must be an array'),
  body('songIds.*').optional().matches(/^(?:[a-zA-Z0-9_-]{11}|(?:dz|au)_[a-zA-Z0-9_-]+)$/).withMessage('Invalid video ID in songIds'),
  validate,
];

const updateProfileValidation = [
  body('username').optional().isLength({ min: 3, max: 30 }).matches(/^[a-zA-Z0-9_]+$/).withMessage('Invalid username'),
  body('firstName').optional().trim().isLength({ min: 1, max: 50 }).withMessage('First name 1-50 chars'),
  body('lastName').optional().trim().isLength({ min: 1, max: 50 }).withMessage('Last name 1-50 chars'),
  body('bio').optional().trim().isLength({ max: 500 }).withMessage('Bio max 500 chars'),
  body('preferences.theme').optional().isIn(['dark', 'light', 'system']).withMessage('Invalid theme'),
  body('preferences.audioQuality').optional().isIn(['low', 'medium', 'high']).withMessage('Invalid audio quality'),
  body('preferences.language').optional().isLength({ min: 2, max: 5 }).withMessage('Invalid language'),
  body('preferences.notifications').optional().isBoolean().withMessage('Notifications must be boolean'),
  validate,
];

const searchValidation = [
  query('query').trim().isLength({ min: 1, max: 100 }).withMessage('Query required (1-100 chars)'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit 1-50'),
  validate,
];

const videoIdValidation = [
  param('videoId').matches(/^(?:[a-zA-Z0-9_-]{11}|(?:dz|au)_[a-zA-Z0-9_-]+)$/).withMessage('Valid video/track ID required'),
  validate,
];

const playlistIdValidation = [
  param('playlistId').isMongoId().withMessage('Valid playlist ID required'),
  validate,
];

const userIdValidation = [
  param('userId').isMongoId().withMessage('Valid user ID required'),
  validate,
];

const historyIdValidation = [
  param('historyId').isMongoId().withMessage('Valid history ID required'),
  validate,
];

const historyValidation = [
  body('playDuration').isInt({ min: 0 }).withMessage('Play duration must be positive integer'),
  body('totalDuration').isInt({ min: 1 }).withMessage('Total duration required'),
  validate,
];

const qualityValidation = [
  query('quality').optional().isIn(['low', 'medium', 'high']).withMessage('Invalid quality'),
  validate,
];

module.exports = {
  validate,
  registerValidation,
  loginValidation,
  refreshTokenValidation,
  googleAuthValidation,
  forgotPasswordValidation,
  playlistValidation,
  addSongValidation,
  updatePlaylistValidation,
  reorderValidation,
  updateProfileValidation,
  searchValidation,
  videoIdValidation,
  playlistIdValidation,
  userIdValidation,
  historyIdValidation,
  historyValidation,
  qualityValidation,
};