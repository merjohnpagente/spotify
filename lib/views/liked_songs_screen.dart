import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';
import 'package:spotify_fy/widgets/shimmer.dart';

class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Liked Songs',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: liked.when(
        data: (songs) => songs.isEmpty
            ? const Center(
                child: Text(
                  'No liked songs yet',
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
                        '${songs.length} songs',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _playAll(context, ref, songs),
                        icon: const Icon(Icons.play_circle_fill, color: SpotifyColors.primaryAccent, size: 20),
                        label: const Text(
                          'Play All',
                          style: TextStyle(color: SpotifyColors.primaryAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...songs.asMap().entries.map((entry) => SearchResultCard(
                        title: entry.value.title,
                        artist: entry.value.artist,
                        imageUrl: entry.value.thumbnailUrl,
                        onPlay: () => _playSong(context, ref, songs, entry.key),
                        onTap: () => _playSong(context, ref, songs, entry.key),
                      )),
                ],
              ),
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load liked songs',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(likedSongsProvider),
                icon: const Icon(Icons.refresh, color: SpotifyColors.primaryAccent, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: SpotifyColors.primaryAccent),
                ),
              ),
            ],
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