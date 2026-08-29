const Song = require('../src/models/Song');

describe('Song model defaults post-M2', () => {
  const makeSong = (overrides = {}) =>
    new Song({
      videoId: 'abc123DEF45',
      title: 'T',
      artist: 'A',
      duration: 0,
      thumbnailUrl: 'https://i.ytimg.com/vi/abc/hqdefault.jpg',
      ...overrides,
    });

  test('defaults channelId to unknown when missing', () => {
    const s = makeSong();
    expect(s.channelId).toBe('unknown');
  });

  test('duration defaults to 0 and respects explicit 0', () => {
    const s = makeSong({ duration: 0 });
    expect(s.duration).toBe(0);
  });

  test('viewCount defaults to 0', () => {
    const s = makeSong();
    expect(s.viewCount).toBe(0);
  });

  test('thumbnailUrl is kept when provided', () => {
    const s = makeSong();
    expect(s.thumbnailUrl).toBe('https://i.ytimg.com/vi/abc/hqdefault.jpg');
  });

  test('explicit defaults to false', () => {
    const s = makeSong();
    expect(s.explicit).toBe(false);
  });

  test('language defaults to en', () => {
    const s = makeSong();
    expect(s.language).toBe('en');
  });

  test('album defaults to empty string', () => {
    const s = makeSong();
    expect(s.album).toBe('');
  });

  test('isAvailable defaults to true', () => {
    const s = makeSong();
    expect(s.isAvailable).toBe(true);
  });

  test('accessCount defaults to 0', () => {
    const s = makeSong();
    expect(s.accessCount).toBe(0);
  });

  test('audioUrlCached defaults to null', () => {
    const s = makeSong();
    expect(s.audioUrlCached).toBeNull();
  });

  test('audioExtractedAt defaults to null', () => {
    const s = makeSong();
    expect(s.audioExtractedAt).toBeNull();
  });

  test('combined defaults check via example from spec', () => {
    const s = new Song({
      videoId: 'abc123DEF45',
      title: 'T',
      artist: 'A',
      duration: 0,
      thumbnailUrl: 'https://i.ytimg.com/vi/abc/hqdefault.jpg',
    });
    expect(s.channelId).toBe('unknown');
    expect(s.duration).toBe(0);
    expect(s.viewCount).toBe(0);
  });
});

describe('Song isAudioCacheValid', () => {
  const makeSong = () =>
    new Song({
      videoId: 'abc123DEF45',
      title: 'T',
      artist: 'A',
      duration: 0,
      thumbnailUrl: 'https://i.ytimg.com/vi/abc/hqdefault.jpg',
    });

  test('returns true when cached URL fresh', () => {
    const s = makeSong();
    s.audioUrlCached = 'https://googlevideo.com/a';
    s.audioExtractedAt = new Date();
    expect(s.isAudioCacheValid()).toBe(true);
  });

  test('returns false when cache expired (>5h, 6h ago)', () => {
    const s = makeSong();
    s.audioUrlCached = 'https://googlevideo.com/a';
    s.audioExtractedAt = new Date(Date.now() - 6 * 60 * 60 * 1000);
    expect(s.isAudioCacheValid()).toBe(false);
  });

  test('returns false when audioUrlCached missing', () => {
    const s = makeSong();
    s.audioUrlCached = null;
    s.audioExtractedAt = new Date();
    expect(s.isAudioCacheValid()).toBe(false);
  });

  test('returns false when audioExtractedAt missing', () => {
    const s = makeSong();
    s.audioUrlCached = 'https://googlevideo.com/a';
    s.audioExtractedAt = null;
    expect(s.isAudioCacheValid()).toBe(false);
  });

  test('returns false when both missing', () => {
    const s = makeSong();
    s.audioUrlCached = null;
    s.audioExtractedAt = null;
    expect(s.isAudioCacheValid()).toBe(false);
  });

  test('returns true just under 5h', () => {
    const s = makeSong();
    s.audioUrlCached = 'https://googlevideo.com/a';
    s.audioExtractedAt = new Date(Date.now() - 4 * 60 * 60 * 1000);
    expect(s.isAudioCacheValid()).toBe(true);
  });

  test('returns false just over 5h (5h + 1s)', () => {
    const s = makeSong();
    s.audioUrlCached = 'https://googlevideo.com/a';
    s.audioExtractedAt = new Date(Date.now() - (5 * 60 * 60 * 1000 + 1000));
    expect(s.isAudioCacheValid()).toBe(false);
  });
});
