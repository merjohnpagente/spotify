import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/views/artist_screen.dart';
import 'package:spotify_fy/views/genre_songs_screen.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Listening Stats',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: stats.when(
        data: (data) => _buildBody(context, ref, data),
        loading: () => const Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load your stats',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(userStatsProvider),
                child: const Text(
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

  Widget _buildBody(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final totalListening = (data['totalListeningTime'] as num?)?.toInt() ?? 0;
    final totalPlays = (data['totalSongsPlayed'] as num?)?.toInt() ?? 0;
    final topGenres = (data['topGenres'] as List?) ?? [];
    final topArtists = (data['topArtists'] as List?) ?? [];
    final topSongs = (data['topSongs'] as List?) ?? [];

    final hours = (totalListening / 3600).floor();
    final minutes = ((totalListening % 3600) / 60).floor();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(userStatsProvider),
      color: SpotifyColors.primaryAccent,
      backgroundColor: SpotifyColors.cardBackground,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Time Listened',
                  value: hours > 0 ? '$hours h $minutes m' : '$minutes min',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'Songs Played',
                  value: '$totalPlays',
                  icon: Icons.play_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (topGenres.isNotEmpty) ...[
            const Text(
              'Top Genres',
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: topGenres.map<Widget>((g) {
                final name = (g['genre'] as String?) ?? '';
                final count = (g['count'] as num?)?.toInt() ?? 0;
                return _Chip(
                  label: name,
                  sub: '$count plays',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenreSongsScreen(genre: name),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
          if (topArtists.isNotEmpty) ...[
            const Text(
              'Top Artists',
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topArtists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final a = topArtists[index];
                final name = (a['artist'] as String?) ?? '';
                final count = (a['count'] as num?)?.toInt() ?? 0;
                return _ArtistRow(
                  rank: index + 1,
                  name: name,
                  sub: '$count plays',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ArtistScreen(artist: name)),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if (topSongs.isNotEmpty) ...[
            const Text(
              'Top Songs',
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topSongs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final song = topSongs[index];
                final s = song is Map<String, dynamic>
                    ? Song.fromJson(song)
                    : null;
                if (s == null) return const SizedBox.shrink();
                return SearchResultCard(
                  title: '${index + 1}. ${s.title}',
                  artist: s.artist,
                  imageUrl: s.thumbnailUrl,
                  onPlay: () => playSongAndOpenPlayer(context, ref, s),
                  onTap: () => playSongAndOpenPlayer(context, ref, s),
                );
              },
            ),
          ],
          if (topGenres.isEmpty && topArtists.isEmpty && topSongs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Play some songs to see your stats here',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SpotifyColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SpotifyColors.primaryAccent, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback? onTap;

  const _Chip({required this.label, required this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: SpotifyColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  final int rank;
  final String name;
  final String sub;
  final VoidCallback? onTap;

  const _ArtistRow({
    required this.rank,
    required this.name,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 28,
        child: Text(
          '$rank',
          style: const TextStyle(
            color: SpotifyColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(
          color: SpotifyColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
    );
  }
}
