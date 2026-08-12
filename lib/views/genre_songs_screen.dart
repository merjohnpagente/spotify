import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class GenreSongsScreen extends ConsumerWidget {
  const GenreSongsScreen({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(genreSongsProvider(genre));

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: Text(
          genre,
          style: const TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: songs.when(
        data: (list) => list.isEmpty
            ? const Center(
                child: Text(
                  'No songs in this genre yet',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${list.length} songs',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _playAll(context, ref, list),
                        icon: const Icon(Icons.play_circle_fill, color: SpotifyColors.primaryAccent, size: 20),
                        label: const Text(
                          'Play All',
                          style: TextStyle(color: SpotifyColors.primaryAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...list.asMap().entries.map((entry) => SearchResultCard(
                        title: entry.value.title,
                        artist: entry.value.artist,
                        imageUrl: entry.value.thumbnailUrl,
                        onPlay: () => _playSong(context, ref, list, entry.key),
                        onTap: () => _playSong(context, ref, list, entry.key),
                      )),
                ],
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load songs',
            style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _playSong(BuildContext context, WidgetRef ref, List<Song> queue, int index) {
    playSongAndOpenPlayer(context, ref, queue[index], queue: queue);
  }

  void _playAll(BuildContext context, WidgetRef ref, List<Song> queue) {
    playSongAndOpenPlayer(context, ref, queue.first, queue: queue);
  }
}