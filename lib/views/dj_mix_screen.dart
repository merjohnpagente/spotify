import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';
import 'package:spotify_fy/widgets/shimmer.dart';

/// Smart Mix ("AI DJ" v1) — a personal mix built from liked + history +
/// trending + recommendations. Fully functional playback, no backend change.
class DjMixScreen extends ConsumerWidget {
  const DjMixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mix = ref.watch(djMixProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Smart Mix',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SpotifyColors.textPrimary),
            tooltip: 'Regenerate mix',
            onPressed: () => ref.invalidate(djMixProvider),
          ),
        ],
      ),
      body: mix.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Play or like some songs first,\nthen I can build your mix.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(djMixProvider),
                      icon: const Icon(Icons.refresh,
                          color: SpotifyColors.primaryAccent, size: 18),
                      label: const Text('Try again',
                          style: TextStyle(color: SpotifyColors.primaryAccent)),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SpotifyColors.primaryAccent.withValues(alpha: 0.35),
                          SpotifyColors.cardBackground,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: SpotifyColors.primaryAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: SpotifyColors.primaryAccent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Made for you',
                                style: TextStyle(
                                  color: SpotifyColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Based on your likes, history and trending.',
                                style: TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _playAll(context, ref, list),
                      style: FilledButton.styleFrom(
                        backgroundColor: SpotifyColors.primaryAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play My Mix',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...list.asMap().entries.map((entry) => SearchResultCard(
                        title: entry.value.title,
                        artist: entry.value.artist,
                        imageUrl: entry.value.thumbnailUrl,
                        onPlay: () => _playSong(context, ref, list, entry.key),
                        onTap: () => _playSong(context, ref, list, entry.key),
                      )),
                ],
              ),
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not build your mix',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(djMixProvider),
                icon: const Icon(Icons.refresh, color: SpotifyColors.primaryAccent, size: 18),
                label: const Text('Retry',
                    style: TextStyle(color: SpotifyColors.primaryAccent)),
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
