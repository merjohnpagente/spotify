jest.mock('../src/config/redis', () => ({
  cacheGet: jest.fn().mockResolvedValue(null),
  cacheSet: jest.fn().mockResolvedValue(),
  cacheDeletePattern: jest.fn(),
  cacheDelete: jest.fn(),
}));
jest.mock('mongoose', () => ({ connection: { readyState: 0 } }));
jest.mock('../src/models', () => ({
  Song: {
    findOne: jest.fn().mockResolvedValue(null),
    findOneAndUpdate: jest.fn().mockResolvedValue(null),
  },
}));
jest.mock('../src/services/youtubeService', () => ({
  runYtDlp: jest.fn().mockResolvedValue({ url: 'https://googlevideo.com/mock' }),
}));

const audioService = require('../src/services/audioService');

describe('audioService STRATEGIES (mocked, no DB/network)', () => {
  test('exports STRATEGIES array with 6 entries', () => {
    expect(Array.isArray(audioService.STRATEGIES)).toBe(true);
    expect(audioService.STRATEGIES).toHaveLength(6);
  });

  test('first strategy is android', () => {
    expect(audioService.STRATEGIES[0].label).toBe('android');
    expect(audioService.STRATEGIES[0].extractorArgs).toBe('youtube:player_client=android');
  });

  test('second strategy is ios', () => {
    expect(audioService.STRATEGIES[1].label).toBe('ios');
  });

  test('third is mweb and fourth is default', () => {
    expect(audioService.STRATEGIES[2].label).toBe('mweb');
    expect(audioService.STRATEGIES[3].label).toBe('default');
    expect(audioService.STRATEGIES[3].extractorArgs).toBeNull();
  });

  test('fifth is tv_embedded and sixth is web_embedded', () => {
    expect(audioService.STRATEGIES[4].label).toBe('tv_embedded');
    expect(audioService.STRATEGIES[5].label).toBe('web_embedded');
  });

  test('all strategies have label and extractorArgs keys', () => {
    for (const s of audioService.STRATEGIES) {
      expect(typeof s.label).toBe('string');
      expect('extractorArgs' in s).toBe(true);
    }
  });

  test('getPreferredStrategy initially null before any extraction', () => {
    expect(audioService.getPreferredStrategy()).toBeNull();
  });

  test('module exports expected functions', () => {
    expect(typeof audioService.extractAudioUrl).toBe('function');
    expect(typeof audioService.extractWithFallbacks).toBe('function');
    expect(typeof audioService.extractWithStrategy).toBe('function');
    expect(typeof audioService.getPreferredStrategy).toBe('function');
    expect(typeof audioService.getCachedAudioUrl).toBe('function');
    expect(typeof audioService.incrementAccessCount).toBe('function');
  });

  test('STRATEGIES order keeps android first for datacenter fast path', () => {
    const labels = audioService.STRATEGIES.map((s) => s.label);
    expect(labels[0]).toBe('android');
    expect(labels).toEqual(['android', 'ios', 'mweb', 'default', 'tv_embedded', 'web_embedded']);
  });
});
