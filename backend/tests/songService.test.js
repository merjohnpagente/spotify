const youtubeService = require('../src/services/youtubeService');

describe('youtubeService format helpers (no network/DB)', () => {
  test('formatFlatEntry never emits empty channelId', () => {
    const entry = {
      id: 'kJQP7kiw5Fk',
      title: 'Despacito',
      channel: 'Luis Fonsi',
      duration: 282,
      view_count: 100,
      channel_id: '',
    };
    const song = youtubeService.formatFlatEntry(entry);
    expect(song.channelId).toBe('unknown');
    expect(song.channelId).not.toBe('');
  });

  test('formatFlatEntry uses channel_id when present', () => {
    const entry = {
      id: 'kJQP7kiw5Fk',
      title: 'Despacito',
      channel: 'Luis Fonsi',
      channel_id: 'UC0e3QoKp8VYS6v0fnOGX6Vw',
    };
    const song = youtubeService.formatFlatEntry(entry);
    expect(song.channelId).toBe('UC0e3QoKp8VYS6v0fnOGX6Vw');
  });

  test('formatFlatEntry defaults duration to 0 for missing/NaN', () => {
    const entry = { id: 'abc123DEF45', title: 'T', channel: 'C' };
    const song = youtubeService.formatFlatEntry(entry);
    expect(song.duration).toBe(0);
  });

  test('formatFlatEntry returns null without id', () => {
    expect(youtubeService.formatFlatEntry({ title: 'no id' })).toBeNull();
    expect(youtubeService.formatFlatEntry(null)).toBeNull();
  });
});
