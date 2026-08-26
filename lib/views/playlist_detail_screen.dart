import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/playlist.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistDetailProvider(playlistId));

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: Text(
          playlist.maybeWhen(
            data: (p) => p.title,
            orElse: () => 'Playlist',
          ),
          style: const TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: playlist.when(
        data: (p) => _buildBody(context, ref, p),
        loading: () => const Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
        error: (e, _) => const Center(
          child: Text(
            'Could not load playlist',
            style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Playlist p) {
    final songs = p.songs;

    return Column(
      children: [
        if (songs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
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
                  onPressed: () => playSongAndOpenPlayer(context, ref, songs.first, queue: songs),
                  icon: const Icon(Icons.play_circle_fill, color: SpotifyColors.primaryAccent, size: 20),
                  label: const Text(
                    'Play All',
                    style: TextStyle(color: SpotifyColors.primaryAccent, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: songs.isEmpty
              ? const Center(
                  child: Text(
                    'No songs in this playlist yet',
                    style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    ...songs.asMap().entries.map((entry) => SearchResultCard(
                          title: entry.value.title,
                          artist: entry.value.artist,
                          imageUrl: entry.value.thumbnailUrl,
                          onPlay: () =>
                              playSongAndOpenPlayer(context, ref, entry.value, queue: songs),
                          onTap: () =>
                              playSongAndOpenPlayer(context, ref, entry.value, queue: songs),
                        )),
                  ],
                ),
        ),
      ],
    );
  }
}