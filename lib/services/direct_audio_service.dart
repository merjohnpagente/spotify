import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// PureTuber-style direct extraction — no server round-trip.
/// Used on Android/iOS where youtubei is not CORS-blocked. Web still uses server proxy.
class DirectAudioService {
  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  /// Returns a direct googlevideo audio URL for [videoId], or null on failure.
  /// PureTuber does the same: calls youtubei player endpoint directly on-device (~0.5-1s).
  Future<String?> getAudioUrl(String videoId, {Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final manifest = await _client.videos.streamsClient
          .getManifest(videoId)
          .timeout(timeout);
      // Prefer audio-only, highest bitrate — same as our server pickAudioUrl
      final audio = manifest.audioOnly;
      if (audio.isEmpty) {
        final muxed = manifest.muxed;
        if (muxed.isNotEmpty) {
          muxed.sort((a, b) => (b.bitrate.bitsPerSecond).compareTo(a.bitrate.bitsPerSecond));
          return muxed.first.url.toString();
        }
        return null;
      }
      // AudioOnly sorted highest bitrate first already, but ensure
      final sorted = audio.toList()
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      // Prefer webm/opus or mp4/aac — both work with audioplayers; pick highest
      return sorted.first.url.toString();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
