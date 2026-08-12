const admin = require('firebase-admin');
const config = require('./index');

let firebaseApp = null;

const initializeFirebase = () => {
  if (firebaseApp) return firebaseApp;

  try {
    if (!config.firebase.projectId || !config.firebase.clientEmail || !config.firebase.privateKey) {
      console.warn('Firebase credentials not configured, skipping initialization');
      return null;
    }

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: config.firebase.projectId,
        clientEmail: config.firebase.clientEmail,
        privateKey: config.firebase.privateKey,
      }),
    });

    console.log('Firebase initialized');
    return firebaseApp;
  } catch (error) {
    console.error('Firebase initialization error:', error);
    return null;
  }
};

const getAuth = () => {
  if (!firebaseApp) initializeFirebase();
  return firebaseApp ? admin.auth() : null;
};

const verifyIdToken = async (idToken) => {
  const auth = getAuth();
  if (!auth) throw new Error('Firebase not initialized');
  return await auth.verifyIdToken(idToken);
};

const createCustomToken = async (uid) => {
  const auth = getAuth();
  if (!auth) throw new Error('Firebase not initialized');
  return await auth.createCustomToken(uid);
};

const getUserByEmail = async (email) => {
  const auth = getAuth();
  if (!auth) throw new Error('Firebase not initialized');
  return await auth.getUserByEmail(email);
};

const createUser = async (userData) => {
  const auth = getAuth();
  if (!auth) throw new Error('Firebase not initialized');
  return await auth.createUser(userData);
};

module.exports = {
  initializeFirebase,
  getAuth,
  verifyIdToken,
  createCustomToken,
  getUserByEmail,
  createUser,
};