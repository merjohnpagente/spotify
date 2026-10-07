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

  /// Requests a password-reset email. The backend always returns a generic
  /// message so accounts can't be enumerated.
  Future<String> forgotPassword({required String email}) async {
    final data = await _api.post(
      '/api/auth/forgot-password',
      body: {'email': email},
      auth: false,
    );
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    }
    return 'If the email exists, a reset link has been sent';
  }

  /// Completes a password reset with the token from the reset email.
  Future<String> resetPassword({required String token, required String password}) async {
    final data = await _api.post(
      '/api/auth/reset-password',
      body: {'token': token.trim(), 'password': password},
      auth: false,
    );
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    }
    return 'Password reset successfully. Please sign in again.';
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