import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const String _accessKey = 'auth_access_token';
  static const String _refreshKey = 'auth_refresh_token';
  static const String _userKey = 'auth_user';

  final SharedPreferences _prefs;

  TokenStore(this._prefs);

  String? get accessToken => _prefs.getString(_accessKey);
  String? get refreshToken => _prefs.getString(_refreshKey);

  Map<String, dynamic>? get cachedUser {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool get hasSession => accessToken != null && refreshToken != null;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    await _prefs.setString(_accessKey, accessToken);
    await _prefs.setString(_refreshKey, refreshToken);
    if (user != null) {
      await _prefs.setString(_userKey, jsonEncode(user));
    }
  }

  Future<void> updateCachedUser(Map<String, dynamic> user) async {
    await _prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
    await _prefs.remove(_userKey);
  }
}