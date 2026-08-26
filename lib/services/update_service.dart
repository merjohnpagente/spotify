import 'dart:convert';

import 'package:http/http.dart' as http;

import '../version.dart';

/// Describes an available app update.
class UpdateInfo {
  final String latestVersion;
  final String apkUrl;
  final String? message;

  const UpdateInfo({
    required this.latestVersion,
    required this.apkUrl,
    this.message,
  });
}

/// Checks GitHub Pages for a newer app version. Fails silent - the update
/// prompt is best-effort and must never block or break the app.
class UpdateService {
  final http.Client _client;

  UpdateService([http.Client? client]) : _client = client ?? http.Client();

  /// Returns [UpdateInfo] when the published version is newer than the
  /// running one, otherwise null.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _client
          .get(Uri.parse(AppVersion.updateCheckUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final latest = data['version'] as String?;
      if (latest == null || !_isNewer(latest, AppVersion.version)) return null;

      return UpdateInfo(
        latestVersion: latest,
        apkUrl: (data['apkUrl'] as String?) ?? AppVersion.apkUrl,
        message: data['message'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String candidate, String current) {
    final a = candidate.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final b = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  void dispose() {
    _client.close();
  }
}
