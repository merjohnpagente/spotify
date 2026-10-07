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

  /// Direct attempt is ONE parallel round bounded by [timeout] (~4s): all
  /// hosts race at once, first audio URL wins. On total failure we return
  /// null fast so the player falls back to the server proxy immediately
  /// instead of burning ~48s trying dead hosts one-by-one.
  Future<String?> getAudioUrl(String videoId, {Duration timeout = const Duration(seconds: 4)}) async {
    if (videoId.startsWith('dz_') || videoId.startsWith('au_')) return null;
    try {
      final results = await Future.wait([
        ..._invidiousHosts.map((host) => _fetchViaAllOrigins(host, videoId, timeout)),
        ..._invidiousHosts.map((host) => _fetchDirect(host, videoId, timeout)),
      ]).timeout(timeout + const Duration(seconds: 1));
      for (final url in results) {
        if (url != null) return url;
      }
    } catch (_) {
      // Timeout or failure — fall back to server proxy immediately.
    }
    return null;
  }

  Future<String?> _fetchViaAllOrigins(String host, String videoId, Duration timeout) async {
    try {
      final invUrl = '$host/api/v1/videos/$videoId';
      final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(invUrl)}';
      final resp = await http.get(Uri.parse(proxyUrl)).timeout(timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return _pickInvidiousUrl(data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchDirect(String host, String videoId, Duration timeout) async {
    try {
      final resp = await http.get(Uri.parse('$host/api/v1/videos/$videoId')).timeout(timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return _pickInvidiousUrl(data);
    } catch (_) {
      return null;
    }
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
}
