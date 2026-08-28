import 'dart:convert';
import 'package:http/http.dart' as http;

/// Chrome-only direct path via CORS proxy — mirrors PureTuber's
/// youtubei call but bypasses Render cold start. Falls back to server proxy.
class WebAudioService {
  static const _corsProxy = 'https://corsproxy.io/?';
  static const _playerUrl =
      'https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  Future<String?> getAudioUrl(String videoId, {Duration timeout = const Duration(seconds: 8)}) async {
    // Try primary CORS proxy
    var url = await _tryProxy('$_corsProxy$_playerUrl', videoId, timeout);
    if (url != null) return url;
    // Fallback proxy (if corsproxy.io rate-limits)
    url = await _tryProxy('https://api.allorigins.win/raw?url=${Uri.encodeComponent(_playerUrl)}', videoId, timeout);
    return url;
  }

  Future<String?> _tryProxy(String proxyUrl, String videoId, Duration timeout) async {
    try {
      final body = jsonEncode({
        'context': {
          'client': {
            'hl': 'en',
            'gl': 'US',
            'clientName': 'ANDROID',
            'clientVersion': '19.09.37',
            'androidSdkVersion': 30,
            'userAgent': 'com.google.android.youtube/19.09.37 (Linux; UTV; SM-S911B) gzip',
          }
        },
        'videoId': videoId,
        'playbackContext': {
          'contentPlaybackContext': {'html5Preference': 'HTML5_PREF_W_CON'}
        },
        'contentCheckOk': true,
        'racyCheckOk': true,
      });
      final resp = await http
          .post(Uri.parse(proxyUrl),
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final streamingData = data['streamingData'] as Map<String, dynamic>?;
      if (streamingData == null) return null;
      final List formats = [
        ...?streamingData['adaptiveFormats'] as List?,
        ...?streamingData['formats'] as List?,
      ];
      // Prefer audio mime
      final audio = formats.where((f) {
        final m = (f as Map)['mimeType']?.toString() ?? '';
        final url = f['url'] as String?;
        return url != null && m.contains('audio');
      }).toList();
      List pickFrom = audio.isNotEmpty ? audio : formats;
      if (pickFrom.isEmpty) return null;
      pickFrom.sort((a, b) {
        final ba = (a as Map)['bitrate'] as int? ?? 0;
        final bb = (b as Map)['bitrate'] as int? ?? 0;
        return bb.compareTo(ba);
      });
      return (pickFrom.first as Map)['url'] as String?;
    } catch (_) {
      return null;
    }
  }
}
