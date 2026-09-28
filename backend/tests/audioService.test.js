jest.mock('../src/config/redis', () => ({
  cacheGet: jest.fn(),
  cacheSet: jest.fn(),
  cacheDeletePattern: jest.fn(),
  cacheDelete: jest.fn(),
}));
jest.mock('mongoose', () => ({ connection: { readyState: 0 } }));
jest.mock('../src/models', () => ({
  Song: {
    findOne: jest.fn(),
    findOneAndUpdate: jest.fn(),
  },
}));
jest.mock('../src/services/youtubeService', () => ({
  runYtDlp: jest.fn(),
}));
jest.mock('../src/services/audiusService', () => ({
  getStreamUrl: jest.fn().mockResolvedValue(null),
  searchSongs: jest.fn().mockResolvedValue([]),
}));
jest.mock('../src/services/deezerService', () => ({
  getPreviewUrl: jest.fn().mockResolvedValue(null),
  getSongById: jest.fn().mockResolvedValue(null),
}));

const { cacheGet, cacheSet, cacheDelete } = require('../src/config/redis');
const mongoose = require('mongoose');
const { Song } = require('../src/models');
const { runYtDlp } = require('../src/services/youtubeService');
const config = require('../src/config');
const audioService = require('../src/services/audioService');

// Deterministic network: Invidious always loses the race in tests, so
// Promise.any settles on the mocked yt-dlp (also stops leaked real fetches).
const fetchSpy = jest.spyOn(global, 'fetch').mockRejectedValue(new Error('no network in tests'));

afterAll(() => fetchSpy.mockRestore());

describe('audioService race + TTL (M5)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(null);
    runYtDlp.mockResolvedValue({ url: 'https://rr3---sn.googlevideo.com/stream' });
    fetchSpy.mockRejectedValue(new Error('no network in tests'));
    audioService.resetInvidiousCircuit();
  });

  test('AUDIO_CACHE_TTL_HOURS default is 5 (below 6h googlevideo expiry)', () => {
    expect(config.audio.cacheTtlHours).toBe(5);
  });

  test('extractAudioUrl short-circuits on Redis cache hit without yt-dlp', async () => {
    cacheGet.mockResolvedValue({ url: 'https://cached.googlevideo.com/x' });
    const url = await audioService.extractAudioUrl('kJQP7kiw5Fk');
    expect(url).toBe('https://cached.googlevideo.com/x');
    expect(runYtDlp).not.toHaveBeenCalled();
    expect(cacheSet).not.toHaveBeenCalled();
  });

  test('extractAudioUrl falls through to extraction on cache miss', async () => {
    cacheGet.mockResolvedValue(null);
    const url = await audioService.extractAudioUrl('kJQP7kiw5Fk');
    expect(url).toContain('googlevideo.com');
    expect(runYtDlp).toHaveBeenCalled();
    expect(cacheSet).toHaveBeenCalledWith(
      'audio:kJQP7kiw5Fk',
      expect.objectContaining({ url: expect.stringContaining('googlevideo.com') }),
      5 * 60 * 60
    );
  });

  test('extractAudioUrl caches with 5h TTL (18000s)', async () => {
    cacheGet.mockResolvedValue(null);
    await audioService.extractAudioUrl('kJQP7kiw5Fk');
    const ttl = cacheSet.mock.calls[0][2];
    expect(ttl).toBe(5 * 60 * 60);
  });
});

describe('audioService DoD#4 — no proxy persistence (B2)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(null);
    fetchSpy.mockRejectedValue(new Error('no network in tests'));
    audioService.resetInvidiousCircuit();
  });

  test('non-googlevideo URL is returned but never cached (redis or mongo)', async () => {
    runYtDlp.mockResolvedValue({ url: 'https://proxy.invidious.example/stream.mp3' });
    const url = await audioService.extractAudioUrl('kJQP7kiw5Fk');
    expect(url).toBe('https://proxy.invidious.example/stream.mp3');
    expect(Song.findOneAndUpdate).not.toHaveBeenCalled();
    expect(cacheSet).not.toHaveBeenCalled();
  });

  test('clearAudioCache wipes redis key and unsets mongo fields', async () => {
    mongoose.connection.readyState = 1;
    try {
      await audioService.clearAudioCache('kJQP7kiw5Fk');
      expect(cacheDelete).toHaveBeenCalledWith('audio:kJQP7kiw5Fk');
      expect(Song.findOneAndUpdate).toHaveBeenCalledWith(
        { videoId: 'kJQP7kiw5Fk' },
        { audioUrlCached: null, audioExtractedAt: null }
      );
    } finally {
      mongoose.connection.readyState = 0;
    }
  });

  test('clearAudioCache never throws when DB is down', async () => {
    mongoose.connection.readyState = 0;
    await expect(audioService.clearAudioCache('kJQP7kiw5Fk')).resolves.toBeUndefined();
    expect(cacheDelete).toHaveBeenCalledWith('audio:kJQP7kiw5Fk');
    expect(Song.findOneAndUpdate).not.toHaveBeenCalled();
  });
});

describe('audioService failure path (B5) — no double-retry, bot-check bail', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(null);
    fetchSpy.mockRejectedValue(new Error('no network in tests'));
    audioService.resetInvidiousCircuit();
  });

  afterAll(() => audioService.resetInvidiousCircuit());

  const BOT_MSG =
    'Command failed with exit code 1: yt-dlp https://www.youtube.com/watch?v=x\n' +
    'ERROR: [youtube] x: Sign in to confirm you\u2019re not a bot. Use --cookies-from-browser';

  test('bot-check on 2 clients bails early instead of burning all 6 strategies', async () => {
    runYtDlp.mockRejectedValue(new Error(BOT_MSG));
    await expect(audioService.extractWithFallbacks('https://www.youtube.com/watch?v=x')).rejects.toThrow();
    expect(runYtDlp).toHaveBeenCalledTimes(2);
  });

  test('generic errors still try every strategy (no premature bail)', async () => {
    runYtDlp.mockRejectedValue(new Error('ERROR: format not available'));
    await expect(audioService.extractWithFallbacks('https://www.youtube.com/watch?v=x')).rejects.toThrow();
    expect(runYtDlp).toHaveBeenCalledTimes(6); // STRATEGIES.length
  });

  test('extractAudioUrl does NOT re-run the whole chain after the race rejects', async () => {
    runYtDlp.mockRejectedValue(new Error(BOT_MSG));
    await expect(audioService.extractAudioUrl('kJQP7kiw5Fk')).rejects.toThrow('Failed to extract audio');
    // Old bug: Promise.any catch re-ran fetchViaInvidious + extractWithFallbacks
    // (+70s). Now each path runs exactly once: 2 yt-dlp calls, no second chain.
    expect(runYtDlp).toHaveBeenCalledTimes(2);
    expect(fetchSpy).toHaveBeenCalled(); // invidious side still ran once (raced)
    expect(cacheSet).not.toHaveBeenCalled();
  });

  test('invidious winner is remembered as preferredStrategy when googlevideo', async () => {
    runYtDlp.mockRejectedValue(new Error('ERROR: generic yt failure'));
    fetchSpy.mockResolvedValue({
      ok: true,
      json: async () => ({
        adaptiveFormats: [
          { type: 'audio/mp4', bitrate: 128000, url: 'https://rr1---sn.googlevideo.com/v.mp4' },
        ],
      }),
    });
    const url = await audioService.extractAudioUrl('kJQP7kiw5Fk');
    expect(url).toContain('googlevideo.com');
    expect(audioService.getPreferredStrategy()).toBe('invidious');
  });
});

describe('audioService invidious circuit breaker (B3)', () => {
  beforeEach(() => {
    fetchSpy.mockRejectedValue(new Error('no network in tests'));
    audioService.resetInvidiousCircuit();
  });

  afterAll(() => audioService.resetInvidiousCircuit());

  test('opens after 2 consecutive failed runs, then fails fast without network', async () => {
    expect(audioService.getInvidiousCircuitState().open).toBe(false);

    expect(await audioService.fetchViaInvidious('abc123DEF45')).toBeNull();
    expect(audioService.getInvidiousCircuitState()).toMatchObject({
      open: false,
      consecutiveFails: 1,
    });

    expect(await audioService.fetchViaInvidious('abc123DEF45')).toBeNull();
    expect(audioService.getInvidiousCircuitState()).toMatchObject({
      open: true,
      consecutiveFails: 2,
    });

    // Circuit open: no outbound fetches at all.
    fetchSpy.mockClear();
    expect(await audioService.fetchViaInvidious('abc123DEF45')).toBeNull();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test('resetInvidiousCircuit re-arms the breaker', async () => {
    await audioService.fetchViaInvidious('abc123DEF45');
    await audioService.fetchViaInvidious('abc123DEF45');
    expect(audioService.getInvidiousCircuitState().open).toBe(true);
    audioService.resetInvidiousCircuit();
    expect(audioService.getInvidiousCircuitState()).toMatchObject({
      open: false,
      consecutiveFails: 0,
    });
  });

  test('a successful run resets the failure counter', async () => {
    await audioService.fetchViaInvidious('abc123DEF45'); // fail 1
    fetchSpy.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        adaptiveFormats: [
          { type: 'audio/mp4; codecs="mp4a.40.2"', url: 'https://googlevideo.com/ok' },
        ],
      }),
    });
    const url = await audioService.fetchViaInvidious('abc123DEF45');
    expect(url).toBe('https://googlevideo.com/ok');
    expect(audioService.getInvidiousCircuitState()).toMatchObject({
      open: false,
      consecutiveFails: 0,
    });
  });
});
