import 'package:spotify_fy/models/user_profile.dart';
import 'package:spotify_fy/services/api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<UserProfile> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    final data = await _api.post('/api/auth/register', body: {
      'email': email,
      'password': password,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
    }, auth: false);
    return _sessionResult(data);
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    }, auth: false);
    return _sessionResult(data);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _api.post('/api/auth/logout', body: {'refreshToken': refreshToken}, auth: false);
    } catch (_) {
      // Best-effort server logout
    }
  }

  Future<UserProfile> me() async {
    final data = await _api.get('/api/auth/me');
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> updates) async {
    final data = await _api.patch('/api/auth/me', body: updates);
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  UserProfile _sessionResult(Map<String, dynamic> data) {
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }
}