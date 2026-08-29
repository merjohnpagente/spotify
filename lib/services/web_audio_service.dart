import 'dart:convert';
import 'package:http/http.dart' as http;

/// Chrome-only direct path via CORS proxy — mirrors PureTuber's
/// youtubei call but bypasses Render cold start. Falls back to server proxy.
class WebAudioService {
  // Invidious instances (CORS-enabled, no key, GET) — much more reliable than corsproxy.io POST
  static const _invidiousHosts = [
    'https://inv.tux.pizza',
    'https://yewtu.be',
    'https://vid.puffyan.us',
  ];

  Future<String?> getAudioUrl(String videoId, {Duration timeout = const Duration(seconds: 8)}) async {
    // Primary: Invidious via allorigins raw (bypasses CORS, no API key needed)
    var url = await _tryInvidiousViaAllOrigins(videoId, timeout);
    if (url != null) return url;
    // Direct Invidious (if browser allows CORS — some instances set Access-Control-Allow-Origin:*)
    url = await _tryDirectInvidious(videoId, timeout);
    if (url != null) return url;
    return null;
  }

  Future<String?> _tryInvidiousViaAllOrigins(String videoId, Duration timeout) async {
    for (final host in _invidiousHosts) {
      try {
        final invUrl = '$host/api/v1/videos/$videoId';
        final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(invUrl)}';
        final resp = await http.get(Uri.parse(proxyUrl)).timeout(timeout);
        if (resp.statusCode != 200) continue;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = _pickInvidiousUrl(data);
        if (url != null) return url;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<String?> _tryDirectInvidious(String videoId, Duration timeout) async {
    for (final host in _invidiousHosts) {
      try {
        final resp = await http.get(Uri.parse('$host/api/v1/videos/$videoId')).timeout(timeout);
        if (resp.statusCode != 200) continue;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = _pickInvidiousUrl(data);
        if (url != null) return url;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String? _pickInvidiousUrl(Map<String, dynamic> data) {
    final List adaptive = (data['adaptiveFormats'] as List?) ?? [];
    final audio = adaptive.where((f) {
      final m = (f as Map)['type']?.toString() ?? '';
      final u = f['url'] as String?;
      return u != null && m.contains('audio');
    }).toList();
    final pick = audio.isNotEmpty ? audio : adaptive;
    if (pick.isEmpty) return null;
    pick.sort((a, b) => ((b as Map)['bitrate'] as int? ?? 0).compareTo((a as Map)['bitrate'] as int? ?? 0));
    return (pick.first as Map)['url'] as String?;
  }

  // ignore: unused_element
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
