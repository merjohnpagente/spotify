const request = require('supertest');
const app = require('../src/app');

describe('Health & baseline', () => {
  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /api/status returns service ok', async () => {
    const res = await request(app).get('/api/status');
    expect(res.status).toBe(200);
    expect(res.body.service).toBe('spotify-clone-api');
  });

  test('unknown route returns 404', async () => {
    const res = await request(app).get('/api/nonexistent');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Route not found');
  });
});

describe('Validation guards (no DB needed)', () => {
  test('register rejects invalid email', async () => {
    const res = await request(app).post('/api/auth/register').send({
      email: 'not-an-email',
      password: 'password123',
      username: 'valid_user',
      firstName: 'John',
      lastName: 'Doe',
    });
    expect(res.status).toBe(400);
  });

  test('register rejects short password', async () => {
    const res = await request(app).post('/api/auth/register').send({
      email: 'john@example.com',
      password: 'short',
      username: 'valid_user',
      firstName: 'John',
      lastName: 'Doe',
    });
    expect(res.status).toBe(400);
  });

  test('register rejects invalid username', async () => {
    const res = await request(app).post('/api/auth/register').send({
      email: 'john@example.com',
      password: 'password123',
      username: 'bad username!',
      firstName: 'John',
      lastName: 'Doe',
    });
    expect(res.status).toBe(400);
  });

  test('login rejects invalid email', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: 'not-an-email',
      password: 'password123',
    });
    expect(res.status).toBe(400);
  });

  test('search requires query param', async () => {
    const res = await request(app).get('/api/songs/search');
    expect(res.status).toBe(400);
  });

  test('search rejects empty query', async () => {
    const res = await request(app).get('/api/songs/search?query=');
    expect(res.status).toBe(400);
  });

  test('song by id rejects malformed video id', async () => {
    const res = await request(app).get('/api/songs/12345');
    expect(res.status).toBe(400);
  });

  test('playlist id validates mongo id', async () => {
    const res = await request(app).get('/api/playlists/not-a-mongo-id');
    expect(res.status).toBe(400);
  });

  test('protected route without token returns 401', async () => {
    const res = await request(app).get('/api/songs/me/liked');
    expect(res.status).toBe(401);
  });

  test('refresh rejects missing refreshToken', async () => {
    const res = await request(app).post('/api/auth/refresh').send({});
    expect(res.status).toBe(400);
  });
});