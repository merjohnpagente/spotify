import 'package:spotify_fy/models/user_profile.dart';
import 'package:spotify_fy/services/api_client.dart';

class UserService {
  final ApiClient _api;

  UserService(this._api);

  Future<UserProfile> publicProfile(String userId) async {
    final data = await _api.get('/api/users/$userId/profile', auth: false);
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> follow(String userId) async {
    await _api.post('/api/users/$userId/follow');
  }

  Future<void> unfollow(String userId) async {
    await _api.delete('/api/users/$userId/follow');
  }

  Future<bool> isFollowing(String userId) async {
    final data = await _api.get('/api/users/$userId/following-status');
    return (data as Map<String, dynamic>)['isFollowing'] as bool? ?? false;
  }

  Future<List<Map<String, dynamic>>> searchHistory({int limit = 20}) async {
    final data = await _api.get('/api/users/me/search-history?limit=$limit');
    return (data as Map<String, dynamic>)['results'] as List<Map<String, dynamic>>? ?? [];
  }

  Future<void> deleteSearchHistoryEntry(String historyId) async {
    await _api.delete('/api/users/me/search-history/$historyId');
  }

  Future<void> clearSearchHistory() async {
    await _api.delete('/api/users/me/search-history');
  }
}