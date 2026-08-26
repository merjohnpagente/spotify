const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const https = require('node:https');
const config = require('./index');

let firebaseApp = null;

const CERT_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const CERT_CACHE_TTL = 60 * 60 * 1000; // 1 hour
let certCache = { certs: null, fetchedAt: 0 };

const fetchPublicCerts = () =>
  new Promise((resolve, reject) => {
    https
      .get(CERT_URL, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (parseError) {
            reject(parseError);
          }
        });
      })
      .on('error', reject);
  });

// Verifies a Firebase ID token using Google's public certificates.
// Only requires the Firebase project ID - no service account key.
const verifyIdTokenWithPublicCerts = async (idToken) => {
  const projectId = config.firebase.projectId;
  if (!projectId) throw new Error('Firebase project not configured');

  if (!certCache.certs || Date.now() - certCache.fetchedAt > CERT_CACHE_TTL) {
    certCache = { certs: await fetchPublicCerts(), fetchedAt: Date.now() };
  }

  const decoded = jwt.decode(idToken, { complete: true });
  if (!decoded || !decoded.header || !decoded.header.kid) {
    throw new Error('Malformed ID token');
  }

  const cert = certCache.certs[decoded.header.kid];
  if (!cert) throw new Error('Unknown token signing key');

  const payload = jwt.verify(idToken, cert, {
    algorithms: ['RS256'],
    audience: projectId,
    issuer: `https://securetoken.google.com/${projectId}`,
  });

  return {
    uid: payload.user_id || payload.sub,
    email: payload.email,
    name: payload.name,
    picture: payload.picture,
    ...payload,
  };
};

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
  if (auth) return await auth.verifyIdToken(idToken);
  // No service account configured - verify with Google's public certs.
  return await verifyIdTokenWithPublicCerts(idToken);
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