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

const { cacheGet, cacheSet } = require('../src/config/redis');
const { Song } = require('../src/models');
const { runYtDlp } = require('../src/services/youtubeService');
const config = require('../src/config');
const audioService = require('../src/services/audioService');

describe('audioService race + TTL (M5)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    cacheGet.mockResolvedValue(null);
    runYtDlp.mockResolvedValue({ url: 'https://rr3---sn.googlevideo.com/stream' });
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
