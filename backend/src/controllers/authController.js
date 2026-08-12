const { auth } = require('../services');

const register = async (req, res, next) => {
  try {
    const { email, password, username, firstName, lastName } = req.body;
    const result = await auth.registerWithEmail(email, password, username, firstName, lastName);
    await auth.email.sendWelcomeEmail(email, username);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await auth.loginWithEmail(email, password);
    res.json(result);
  } catch (error) {
    next(error);
  }
};

const googleAuth = async (req, res, next) => {
  try {
    const { idToken } = req.body;
    const result = await auth.loginWithGoogle(idToken);
    res.json(result);
  } catch (error) {
    next(error);
  }
};

const refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    const tokens = await auth.refreshTokens(refreshToken);
    res.json(tokens);
  } catch (error) {
    next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    await auth.logout(refreshToken);
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
};

const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    await auth.getUserProfile(email);
    // In a real app, generate a reset token and send email
    // For now, just return success
    res.json({ message: 'If the email exists, a reset link has been sent' });
  } catch (error) {
    next(error);
  }
};

const getProfile = async (req, res, next) => {
  try {
    const user = await auth.getUserProfile(req.userId);
    res.json(user);
  } catch (error) {
    next(error);
  }
};

const updateProfile = async (req, res, next) => {
  try {
    const user = await auth.updateUserProfile(req.userId, req.body);
    res.json(user);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  googleAuth,
  refreshToken,
  logout,
  forgotPassword,
  getProfile,
  updateProfile,
};