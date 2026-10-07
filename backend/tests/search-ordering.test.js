// Full-song ordering + playlist privacy, no network/DB.
// Runs under jest (npm test); same cases are mirrored in a plain-node
// harness during development.
const mockYt = (id) => ({
  videoId: id, title: `YT ${id}`, artist: 'YT Artist', duration: 200,
  thumbnailUrl: '', viewCount: 1, channelId: 'c', genre: '', language: 'en', explicit: false,
});
const mockAu = (id) => ({
  videoId: `au_${id}`, title: `AU ${id}`, artist: 'AU Artist', duration: 180,
  thumbnailUrl: '', viewCount: 1, channelId: 'c', genre: '', language: 'en',
  explicit: false, source: 'audius', isPreview: false,
});
const mockDz = (id) => ({
  videoId: `dz_${id}`, title: `DZ ${id}`, artist: 'DZ Artist', duration: 30,
  thumbnailUrl: '', viewCount: 1, channelId: 'c', genre: '', language: 'en',
  explicit: false, source: 'deezer', previewUrl: 'http://x', isPreview: true,
});

let mockYtCalls = 0;

jest.mock('mongoose', () => ({ connection: { readyState: 0 } }));

jest.mock('../src/models', () => ({
  Song: { find: async () => [], findOne: async () => null },
  UserLike: {}, UserHistory: {}, User: {}, Follower: {}, SearchHistory: {},
  Session: {}, PasswordResetToken: {},
  Playlist: {
    findById: async (id) => {
      if (id === 'priv1') {
        return {
          _id: 'priv1', userId: { toString: () => 'owner1' },
          isPublic: false, songIds: [],
          toPublicJSON() { return { id: 'priv1', isPublic: false }; },
        };
      }
      return null;
    },
  },
}));

jest.mock('../src/services/youtubeService', () => ({
  searchSongs: async () => {
    mockYtCalls++;
    return [mockYt('AAA111AAA11'), mockYt('BBB222BBB22')];
  },
  getTrendingSongs: async () => [mockYt('TTT111TTT11')],
  searchByGenre: async () => [mockYt('GGG111GGG11')],
  getSongById: async () => null,
}));

jest.mock('../src/services/deezerService', () => ({
  searchSongs: async () => [mockDz('111'), mockDz('222')],
  getTrendingSongs: async () => [mockDz('333')],
  getSongById: async () => null,
}));

jest.mock('../src/services/audiusService', () => ({
  searchSongs: async () => [mockAu('aaa')],
  getTrendingSongs: async () => [mockAu('bbb')],
}));

jest.mock('../src/services/audioService', () => ({
  extractAudioUrl: async () => 'u',
  incrementAccessCount: async () => {},
  clearAudioCache: async () => {},
}));

jest.mock('../src/config/redis', () => ({
  cacheGet: async () => null,
  cacheSet: async () => {},
  cacheDelete: async () => {},
  cacheDeletePattern: async () => {},
}));

jest.mock('../src/services/imageService', () => ({
  uploadAvatar: async () => ({ secure_url: 'http://img' }),
  uploadPlaylistCover: async () => ({ secure_url: 'http://img' }),
  deleteAvatar: async () => ({}),
}));

const song = require('../src/services/songService');
const playlist = require('../src/services/playlistService');

describe('YouTube-first ordering (full songs, previews last)', () => {
  test('search returns YouTube + Audius before Deezer previews', async () => {
    const results = await song.searchSongs('hello', 5);
    expect(results).toHaveLength(5);
    expect(results[0].videoId).toBe('AAA111AAA11');
    expect(results[1].videoId).toBe('BBB222BBB22');
    expect(results[2].videoId).toBe('au_aaa');
    expect(results[3].videoId).toBe('dz_111');
    expect(results[4].videoId).toBe('dz_222');
    expect(results[0].isPreview).toBe(false);
  });

  test('concurrent identical searches share one YouTube call', async () => {
    mockYtCalls = 0;
    const runs = await Promise.all(
      Array.from({ length: 5 }, () => song.searchSongs('coalesce-me', 5))
    );
    expect(mockYtCalls).toBe(1);
    expect(runs.every((r) => r.length === 5)).toBe(true);
  });

  test('trending and genre lead with YouTube', async () => {
    const trending = await song.getTrendingSongs(5);
    expect(trending[0].videoId).toBe('TTT111TTT11');
    const genre = await song.getSongsByGenre('pop', 5);
    expect(genre[0].videoId).toBe('GGG111GGG11');
  });
});

describe('Playlist privacy', () => {
  test('private playlist songs rejected for strangers', async () => {
    await expect(playlist.getPlaylistSongs('priv1', 'stranger')).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  test('private playlist songs rejected anonymously', async () => {
    await expect(playlist.getPlaylistSongs('priv1', null)).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  test('private playlist songs allowed for the owner', async () => {
    await expect(playlist.getPlaylistSongs('priv1', 'owner1')).resolves.toEqual([]);
  });
});
