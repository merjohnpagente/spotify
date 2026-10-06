import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/theme.dart';

/// Real lyrics bottom sheet powered by the free lrclib API (no key needed).
/// Shows loading, the lyrics, or an honest empty/error state — never a
/// dead "coming soon" button.
Future<void> showLyricsSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SpotifyColors.cardBackground,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _LyricsBody(
        song: song,
        scrollController: scrollController,
      ),
    ),
  );
}

class _LyricsBody extends StatelessWidget {
  final Song song;
  final ScrollController scrollController;

  const _LyricsBody({required this.song, required this.scrollController});

  Future<String?> _fetchLyrics() async {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'artist_name': song.artist,
      'track_name': song.title,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Lyrics request failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    if (json is Map<String, dynamic>) {
      final plain = (json['plainLyrics'] as String?)?.trim();
      if (plain != null && plain.isNotEmpty) return plain;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: SpotifyColors.textSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              song.title,
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              song.artist,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<String?>(
                future: _fetchLyrics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: SpotifyColors.primaryAccent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Finding lyrics…',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lyrics_outlined,
                            color: SpotifyColors.textSecondary,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Could not load lyrics right now.\nCheck your connection and try again.',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  final lyrics = snapshot.data;
                  if (lyrics == null || lyrics.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lyrics_outlined,
                            color: SpotifyColors.textSecondary,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No lyrics found for "${song.title}" yet.',
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      lyrics,
                      style: const TextStyle(
                        color: SpotifyColors.textPrimary,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
