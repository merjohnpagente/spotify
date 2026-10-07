// P0 regression tests that need no DB/Redis: auth gates, validation,
// proxy trust (rate-limit correctness behind Render), limiter config.
const request = require('supertest');
const app = require('../src/app');
const { streamLimiter } = require('../src/middleware');

describe('Security gates (no DB needed)', () => {
  test('debug ytdlp endpoint requires auth', async () => {
    const res = await request(app).get('/api/debug/ytdlp');
    expect(res.status).toBe(401);
  });

  test('private playlist songs route validates id format', async () => {
    const res = await request(app).get('/api/playlists/not-a-mongo-id/songs');
    expect(res.status).toBe(400);
  });

  test('stream route rejects malformed video id', async () => {
    const res = await request(app).get('/api/songs/12345/stream');
    expect(res.status).toBe(400);
  });

  test('audio proxy route rejects malformed video id', async () => {
    const res = await request(app).get('/api/songs/12345/audio');
    expect(res.status).toBe(400);
  });

  test('reset-password rejects missing fields', async () => {
    const res = await request(app).post('/api/auth/reset-password').send({});
    expect(res.status).toBe(400);
  });

  test('reset-password rejects short password', async () => {
    const res = await request(app).post('/api/auth/reset-password').send({
      token: 'a'.repeat(64),
      password: 'short',
    });
    expect(res.status).toBe(400);
  });

  test('playlist cover upload without token returns 401', async () => {
    const res = await request(app).post(
      '/api/playlists/000000000000000000000000/cover'
    );
    expect(res.status).toBe(401);
  });
});

describe('Production hardening config', () => {
  test('trust proxy enabled so rate limits see real client IPs', () => {
    expect(app.get('trust proxy')).toBe(1);
  });

  test('stream limiter middleware is configured', () => {
    expect(typeof streamLimiter).toBe('function');
  });
});
