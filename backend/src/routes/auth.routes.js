const express = require('express');
const {
  authenticate,
  authLimiter,
  registerValidation,
  loginValidation,
  refreshTokenValidation,
  googleAuthValidation,
  forgotPasswordValidation,
  updateProfileValidation,
} = require('../middleware');
const authController = require('../controllers/authController');

const router = express.Router();

router.post('/register', authLimiter, registerValidation, authController.register);
router.post('/login', authLimiter, loginValidation, authController.login);
router.post('/google', authLimiter, googleAuthValidation, authController.googleAuth);
router.post('/refresh', refreshTokenValidation, authController.refreshToken);
router.post('/logout', authLimiter, refreshTokenValidation, authController.logout);
router.post('/forgot-password', authLimiter, forgotPasswordValidation, authController.forgotPassword);

router.get('/me', authenticate, authController.getProfile);
router.patch('/me', authenticate, updateProfileValidation, authController.updateProfile);

module.exports = router;