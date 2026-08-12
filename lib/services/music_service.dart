import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/services/api_client.dart';

class MusicService {
  final ApiClient _api;

  MusicService(this._api);

  Future<List<Song>> search(String query, {int limit = 20}) async {
    final data = await _api.get(
      '/api/songs/search?query=${Uri.encodeQueryComponent(query)}&limit=$limit',
      auth: false,
    );
    return _songList(data);
  }

  Future<List<Song>> trending({int limit = 30}) async {
    final data = await _api.get('/api/songs/trending?limit=$limit', auth: false);
    return _songList(data);
  }

  Future<List<Song>> byGenre(String genre, {int limit = 20}) async {
    final data = await _api.get(
      '/api/songs/genre/${Uri.encodeComponent(genre)}?limit=$limit',
      auth: false,
    );
    return _songList(data);
  }

  Future<Song> getSong(String videoId) async {
    final data = await _api.get('/api/songs/$videoId', auth: false);
    return Song.fromJson(data as Map<String, dynamic>);
  }

  Future<String> getStreamUrl(String videoId, {String? quality}) async {
    final query = quality == null || quality.isEmpty
        ? ''
        : '?quality=${Uri.encodeQueryComponent(quality)}';
    final data = await _api.get('/api/songs/$videoId/stream$query', auth: false);
    return (data as Map<String, dynamic>)['streamUrl'] as String;
  }

  Future<List<Song>> recommendations(String videoId, {int limit = 10}) async {
    final data = await _api.get('/api/songs/$videoId/recommendations?limit=$limit', auth: false);
    return _songList(data);
  }

  Future<void> like(String videoId) async {
    await _api.post('/api/songs/$videoId/like');
  }

  Future<void> unlike(String videoId) async {
    await _api.delete('/api/songs/$videoId/like');
  }

  Future<List<Song>> likedSongs({int limit = 50}) async {
    final data = await _api.get('/api/songs/me/liked?limit=$limit');
    return _songList(data);
  }

  Future<void> addHistory(String videoId, {required int playDuration, required int totalDuration}) async {
    await _api.post('/api/songs/$videoId/history', body: {
      'playDuration': playDuration,
      'totalDuration': totalDuration,
    });
  }

  Future<List<Map<String, dynamic>>> history({int limit = 50}) async {
    final data = await _api.get('/api/songs/me/history?limit=$limit');
    return (data as Map<String, dynamic>)['results'] as List<Map<String, dynamic>>? ?? [];
  }

  Future<void> clearHistory() async {
    await _api.delete('/api/songs/me/history');
  }

  Future<Map<String, dynamic>> stats() async {
    return (await _api.get('/api/songs/me/stats')) as Map<String, dynamic>;
  }

  List<Song> _songList(dynamic data) {
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results
            .whereType<Map<String, dynamic>>()
            .map(Song.fromJson)
            .toList();
      }
    }
    return [];
  }
}