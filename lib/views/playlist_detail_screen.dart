import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/playlist.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';
import 'package:spotify_fy/widgets/shimmer.dart';

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
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: playlist.when(
        data: (p) => _buildBody(context, ref, p),
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load playlist',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(playlistDetailProvider(playlistId)),
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

  Widget _buildBody(BuildContext context, WidgetRef ref, Playlist p) {
    final songs = p.songs;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Playlist header: cover art + title/description (Spotify-style)
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.coverImageUrl!,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ShimmerBox(width: 180, height: 180),
                    errorWidget: (context, url, error) => _coverFallback(),
                  )
                : _coverFallback(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          p.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 16),
        if (songs.isNotEmpty)
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
                onPressed: () => playSongAndOpenPlayer(context, ref, songs.first, queue: songs),
                icon: const Icon(Icons.play_circle_fill, color: SpotifyColors.primaryAccent, size: 20),
                label: const Text(
                  'Play All',
                  style: TextStyle(color: SpotifyColors.primaryAccent, fontSize: 14),
                ),
              ),
            ],
          ),
        if (songs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'No songs in this playlist yet',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
            ),
          )
        else
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
    );
  }

  Widget _coverFallback() {
    return Container(
      width: 180,
      height: 180,
      color: SpotifyColors.cardBackground,
      child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 64),
    );
  }
}
