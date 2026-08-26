import 'package:spotify_fy/models/user_profile.dart';
import 'package:spotify_fy/services/api_client.dart';

/// Result of a successful sign-in: the user plus their session tokens.
class AuthSession {
  final UserProfile user;
  final String accessToken;
  final String refreshToken;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<AuthSession> register({
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
    return _session(data);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    }, auth: false);
    return _session(data);
  }

  /// Exchanges a Firebase ID token (from Google sign-in) for app tokens.
  Future<AuthSession> googleLogin(String idToken) async {
    final data = await _api.post('/api/auth/google', body: {
      'idToken': idToken,
    }, auth: false);
    return _session(data);
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

  AuthSession _session(Map<String, dynamic> data) {
    return AuthSession(
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}