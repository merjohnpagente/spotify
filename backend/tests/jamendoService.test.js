jest.mock('../src/config/redis', () => ({
  cacheGet: jest.fn(),
  cacheSet: jest.fn(),
  cacheDeletePattern: jest.fn(),
  cacheDelete: jest.fn(),
}));

const { cacheGet, cacheSet } = require('../src/config/redis');
const config = require('../src/config');
const jamendo = require('../src/services/jamendoService');

const fetchSpy = jest.spyOn(global, 'fetch');

describe('jamendoService — optional 4th music source', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(null);
    fetchSpy.mockReset();
    config.jamendo.clientId = 'test-cid';
  });

  afterAll(() => {
    fetchSpy.mockRestore();
    config.jamendo.clientId = undefined;
  });

  test('degrades to empty/null without client_id — no network calls', async () => {
    config.jamendo.clientId = '';
    expect(await jamendo.searchSongs('hello', 5)).toEqual([]);
    expect(await jamendo.getTrendingSongs(5)).toEqual([]);
    expect(await jamendo.getSongById('jm_123')).toBeNull();
    expect(await jamendo.getStreamUrl('jm_123')).toBeNull();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test('mapJamendoTrack shapes a track (jm_ prefix, stream url, not preview)', () => {
    const m = jamendo.mapJamendoTrack({
      id: 42,
      name: 'Solar',
      artist_name: 'Nova',
      album_name: 'Light',
      duration: 180,
      album_image: 'https://img/x.jpg',
      popularity: 80,
      artist_id: 7,
      audio: 'https://prod-1.storage.jamendo.com/?trackid=42&format=mp3',
    });
    expect(m).toMatchObject({
      videoId: 'jm_42',
      title: 'Solar',
      artist: 'Nova',
      album: 'Light',
      duration: 180,
      source: 'jamendo',
      isPreview: false,
      audioUrl: expect.stringContaining('trackid=42'),
    });
  });

  test('mapJamendoTrack returns null for junk', () => {
    expect(jamendo.mapJamendoTrack(null)).toBeNull();
    expect(jamendo.mapJamendoTrack({})).toBeNull();
  });

  test('searchSongs maps results, caches, and sends client_id + names', async () => {
    fetchSpy.mockResolvedValue({
      ok: true,
      json: async () => ({
        headers: { code: 0, status: 'success' },
        results: [{ id: 1, name: 'A', artist_name: 'B', duration: 10, audio: 'https://x/a.mp3' }],
      }),
    });
    const songs = await jamendo.searchSongs('hello', 5);
    expect(songs).toHaveLength(1);
    expect(songs[0].videoId).toBe('jm_1');
    expect(cacheSet).toHaveBeenCalled();
    const calledUrl = fetchSpy.mock.calls[0][0];
    expect(calledUrl).toContain('client_id=test-cid');
    expect(calledUrl).toContain('names=hello');
    expect(calledUrl).toContain('api.jamendo.com');
  });

  test('getStreamUrl returns the direct mp3 url', async () => {
    fetchSpy.mockResolvedValue({
      ok: true,
      json: async () => ({
        headers: { code: 0 },
        results: [{ id: 9, name: 'T', artist_name: 'A', duration: 60, audio: 'https://prod-1.storage.jamendo.com/?trackid=9&format=mp3' }],
      }),
    });
    const url = await jamendo.getStreamUrl('jm_9');
    expect(url).toContain('trackid=9');
  });

  test('non-numeric jm_ id short-circuits without fetch', async () => {
    expect(await jamendo.getStreamUrl('jm_notanumber')).toBeNull();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test('API-level error (headers.code != 0) returns [] gracefully', async () => {
    fetchSpy.mockResolvedValue({
      ok: true,
      json: async () => ({ headers: { code: 4, error_message: 'invalid client_id' }, results: [] }),
    });
    expect(await jamendo.searchSongs('x', 5)).toEqual([]);
  });
});
