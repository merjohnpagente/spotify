import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(listeningHistoryProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Listening History',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          history.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: SpotifyColors.textSecondary),
                    onPressed: () => _confirmClear(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: history.when(
        data: (songs) => songs.isEmpty
            ? const Center(
                child: Text(
                  'No listening history yet',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  const SizedBox(height: 8),
                  ...songs.asMap().entries.map((entry) => SearchResultCard(
                        title: entry.value.title,
                        artist: entry.value.artist,
                        imageUrl: entry.value.thumbnailUrl,
                        onPlay: () => _play(context, ref, songs, entry.key),
                        onTap: () => _play(context, ref, songs, entry.key),
                      )),
                ],
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load history',
            style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, List<Song> queue, int index) {
    playSongAndOpenPlayer(context, ref, queue[index], queue: queue);
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.cardBackground,
        title: const Text(
          'Clear listening history?',
          style: TextStyle(color: SpotifyColors.textPrimary),
        ),
        content: const Text(
          'This removes all songs from your listening history. This cannot be undone.',
          style: TextStyle(color: SpotifyColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: SpotifyColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(musicServiceProvider).clearHistory();
                ref.invalidate(listeningHistoryProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not clear history')),
                  );
                }
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFE91E63)),
            ),
          ),
        ],
      ),
    );
  }
}