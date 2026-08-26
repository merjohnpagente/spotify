const jwt = require('jsonwebtoken');
const config = require('../config');
const { User, Session } = require('../models');
const { verifyIdToken } = require('../config/firebase');
const { cacheSet, cacheGet, cacheDelete } = require('../config/redis');

const generateTokens = (user) => {
  const accessToken = jwt.sign(
    { uid: user._id, email: user.email, username: user.username },
    config.jwt.accessSecret,
    { expiresIn: config.jwt.accessExpiry }
  );

  const refreshToken = jwt.sign(
    { uid: user._id, type: 'refresh' },
    config.jwt.refreshSecret,
    { expiresIn: config.jwt.refreshExpiry }
  );

  return { accessToken, refreshToken };
};

const storeRefreshToken = async (userId, refreshToken) => {
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await Session.create({ userId, refreshToken, expiresAt });
  await cacheSet(`refresh:${userId}:${refreshToken}`, { userId }, 30 * 24 * 60 * 60);
};

const verifyAccessToken = (token) => {
  return jwt.verify(token, config.jwt.accessSecret);
};

const verifyRefreshToken = (token) => {
  return jwt.verify(token, config.jwt.refreshSecret);
};

const revokeRefreshToken = async (refreshToken) => {
  await Session.deleteOne({ refreshToken });
  await cacheDelete(`refresh:*:${refreshToken}`);
};

const revokeAllUserTokens = async (userId) => {
  const sessions = await Session.find({ userId }).select('refreshToken');
  for (const session of sessions) {
    await cacheDelete(`refresh:${userId}:${session.refreshToken}`);
  }
  await Session.deleteMany({ userId });
};

const registerWithEmail = async (email, password, username, firstName, lastName) => {
  const existingUser = await User.findOne({ $or: [{ email }, { username }] });
  if (existingUser) {
    throw new Error(existingUser.email === email ? 'Email already registered' : 'Username taken');
  }

  const user = await User.create({
    email,
    passwordHash: password,
    username,
    firstName,
    lastName,
  });

  const tokens = generateTokens(user);
  await storeRefreshToken(user._id, tokens.refreshToken);

  return { user, ...tokens };
};

const loginWithEmail = async (email, password) => {
  const user = await User.findOne({ email }).select('+passwordHash');
  if (!user) throw new Error('Invalid credentials');

  const isMatch = await user.comparePassword(password);
  if (!isMatch) throw new Error('Invalid credentials');

  user.lastLoginAt = new Date();
  await user.save();

  const tokens = generateTokens(user);
  await storeRefreshToken(user._id, tokens.refreshToken);

  return { user, ...tokens };
};

const loginWithGoogle = async (idToken) => {
  const decoded = await verifyIdToken(idToken);
  const { uid, email, name, picture } = decoded;

  // Prevent account takeover via unverified emails: Firebase allows
  // password accounts with unverified addresses. Only trust verified ones.
  if (!email || decoded.email_verified !== true) {
    const err = new Error('Google account email is not verified');
    err.statusCode = 401;
    throw err;
  }

  let user = await User.findOne({ email });
  
  if (!user) {
    const username = email.split('@')[0] + '_' + uid.slice(-6);
    user = await User.create({
      email,
      username: await getUniqueUsername(username),
      passwordHash: uid,
      firstName: name?.split(' ')[0] || 'User',
      lastName: name?.split(' ').slice(1).join(' ') || '',
      avatarUrl: picture,
    });
  }

  user.lastLoginAt = new Date();
  if (picture && !user.avatarUrl) user.avatarUrl = picture;
  await user.save();

  const tokens = generateTokens(user);
  await storeRefreshToken(user._id, tokens.refreshToken);

  return { user, ...tokens };
};

const getUniqueUsername = async (base) => {
  let username = base;
  let counter = 1;
  while (await User.findOne({ username })) {
    username = `${base}_${counter}`;
    counter++;
  }
  return username;
};

const refreshTokens = async (refreshToken) => {
  const decoded = verifyRefreshToken(refreshToken);
  const session = await Session.findOne({ refreshToken, userId: decoded.uid });
  if (!session) throw new Error('Invalid refresh token');

  const user = await User.findById(decoded.uid);
  if (!user) throw new Error('User not found');

  await revokeRefreshToken(refreshToken);

  const tokens = generateTokens(user);
  await storeRefreshToken(user._id, tokens.refreshToken);

  return tokens;
};

const logout = async (refreshToken) => {
  await revokeRefreshToken(refreshToken);
};

const getUserProfile = async (userId) => {
  const cached = await cacheGet(`user:${userId}`);
  if (cached) return cached;

  const user = await User.findById(userId);
  if (!user) throw new Error('User not found');

  await cacheSet(`user:${userId}`, user.toPublicJSON(), 30 * 60);
  return user.toPublicJSON();
};

const updateUserProfile = async (userId, updates) => {
  const allowed = ['username', 'firstName', 'lastName', 'bio', 'avatarUrl', 'preferences'];
  const updateData = {};
  for (const key of allowed) {
    if (updates[key] !== undefined) updateData[key] = updates[key];
  }

  if (updateData.username) {
    const existing = await User.findOne({ username: updateData.username, _id: { $ne: userId } });
    if (existing) throw new Error('Username taken');
  }

  const user = await User.findByIdAndUpdate(userId, updateData, { new: true, runValidators: true });
  await cacheDelete(`user:${userId}`);
  return user.toPublicJSON();
};

module.exports = {
  generateTokens,
  verifyAccessToken,
  verifyRefreshToken,
  registerWithEmail,
  loginWithEmail,
  loginWithGoogle,
  refreshTokens,
  logout,
  getUserProfile,
  updateUserProfile,
  revokeAllUserTokens,
};