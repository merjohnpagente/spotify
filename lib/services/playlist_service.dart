import 'package:spotify_fy/models/playlist.dart';
import 'package:spotify_fy/services/api_client.dart';

class PlaylistService {
  final ApiClient _api;

  PlaylistService(this._api);

  Future<Playlist> create({
    required String title,
    String description = '',
    bool isPublic = true,
  }) async {
    final data = await _api.post('/api/playlists', body: {
      'title': title,
      'description': description,
      'isPublic': isPublic,
    });
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Playlist>> myPlaylists({int limit = 50}) async {
    final data = await _api.get('/api/playlists?limit=$limit');
    return _playlistList(data);
  }

  Future<Playlist> getById(String id) async {
    final data = await _api.get('/api/playlists/$id', auth: false);
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<Playlist> update(String id, Map<String, dynamic> updates) async {
    final data = await _api.patch('/api/playlists/$id', body: updates);
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/playlists/$id');
  }

  Future<Playlist> addSong(String id, String videoId) async {
    final data = await _api.post('/api/playlists/$id/songs', body: {'videoId': videoId});
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<Playlist> removeSong(String id, String videoId) async {
    final data = await _api.delete('/api/playlists/$id/songs/$videoId');
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  List<Playlist> _playlistList(dynamic data) {
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results
            .whereType<Map<String, dynamic>>()
            .map(Playlist.fromJson)
            .toList();
      }
    }
    return [];
  }
}