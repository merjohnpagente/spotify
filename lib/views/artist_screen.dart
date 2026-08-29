import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(searchResultsProvider(artist));

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: SpotifyColors.primaryBackground,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: SpotifyColors.textPrimary, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              artist,
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SliverToBoxAdapter(child: _buildHeader(context, ref, songs)),
          SliverToBoxAdapter(child: _buildBody(context, ref, songs)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<List<Song>> songs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SpotifyColors.primaryAccent.withValues(alpha: 0.9),
                      SpotifyColors.primaryAccent.withValues(alpha: 0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpotifyColors.primaryAccent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: SpotifyColors.textPrimary,
                  size: 56,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Artist',
                      style: TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      style: const TextStyle(
                        color: SpotifyColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => songs.maybeWhen(
                data: (list) {
                  if (list.isNotEmpty) {
                    playSongAndOpenPlayer(context, ref, list.first, queue: list);
                  }
                },
                orElse: () {},
              ),
              icon: const Icon(Icons.play_arrow, color: SpotifyColors.textPrimary, size: 24),
              label: const Text(
                'Shuffle Play',
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotifyColors.primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AsyncValue<List<Song>> songs) {
    return songs.when(
      data: (list) => list.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No songs found for this artist',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              ),
            )
          : ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Popular',
                    style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...list.asMap().entries.map((entry) => SearchResultCard(
                      title: entry.value.title,
                      artist: entry.value.artist,
                      imageUrl: entry.value.thumbnailUrl,
                      onPlay: () => playSongAndOpenPlayer(context, ref, entry.value, queue: list),
                      onTap: () => playSongAndOpenPlayer(context, ref, entry.value, queue: list),
                    )),
              ],
            ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Could not load artist',
            style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
