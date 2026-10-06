import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/utils/route_transitions.dart';
import 'package:spotify_fy/utils/scroll_registry.dart';
import 'package:spotify_fy/views/notifications_screen.dart';
import 'package:spotify_fy/views/settings_screen.dart';
import 'package:spotify_fy/widgets/song_card.dart';
import 'package:spotify_fy/widgets/shimmer.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ScrollRegistry.register(0, _scrollController);
  }

  @override
  void dispose() {
    ScrollRegistry.unregister(0);
    _scrollController.dispose();
    super.dispose();
  }

  /// Computed in [build] so it stays correct across midnight while the app
  /// stays open (was cached once in initState).
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  void _openNotifications() {
    pushFade(context, const NotificationsScreen());
  }

  void _openSettings() {
    pushFade(context, const SettingsScreen());
  }

  void _playSong(BuildContext context, List<Song> queue, int index) {
    playSongAndOpenPlayer(context, ref, queue[index], queue: queue);
  }

  @override
  Widget build(BuildContext context) {
    final trending = ref.watch(trendingSongsProvider);
    final newReleases = ref.watch(newReleasesProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: Image.asset(
          'assets/images/splashh.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: SpotifyColors.textPrimary,
              size: 28,
            ),
            tooltip: 'Notifications',
            onPressed: _openNotifications,
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: SpotifyColors.textPrimary,
              size: 28,
            ),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingSongsProvider);
          ref.invalidate(newReleasesProvider);
        },
        color: SpotifyColors.primaryAccent,
        backgroundColor: SpotifyColors.cardBackground,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Text(
              _greeting,
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trending Now',
                  style: TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            trending.when(
              data: (songs) => songs.isEmpty
                  ? const _EmptySection(text: 'No songs available yet')
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return SongCard(
                          title: song.title,
                          artist: song.artist,
                          imageUrl: song.thumbnailUrl,
                          isPreview: song.isPreview,
                          onPlay: () => _playSong(context, songs, index),
                          onTap: () => _playSong(context, songs, index),
                        );
                      },
                    ),
              loading: () => const SliverGridLoading(rows: 4),
              error: (e, _) => _ErrorSection(
                message: 'Could not load trending songs',
                onRetry: () => ref.invalidate(trendingSongsProvider),
                error: e,
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Releases',
                  style: TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            newReleases.when(
              data: (songs) => songs.isEmpty
                  ? const _EmptySection(text: 'No new releases yet')
                  : SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == songs.length - 1 ? 0 : 16,
                            ),
                            child: SizedBox(
                              width: 150,
                              child: SongCard(
                                title: song.title,
                                artist: song.artist,
                                imageUrl: song.thumbnailUrl,
                                isPreview: song.isPreview,
                                onPlay: () => _playSong(context, songs, index),
                                onTap: () => _playSong(context, songs, index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const _RowLoading(),
              error: (e, _) => _ErrorSection(
                message: 'Could not load new releases',
                onRetry: () => ref.invalidate(newReleasesProvider),
                error: e,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SliverGridLoading extends StatelessWidget {
  const SliverGridLoading({super.key, required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (var i = 0; i < rows * 2; i++) {
      cards.add(
        Container(
          decoration: BoxDecoration(
            color: SpotifyColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return Shimmer(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.75,
        children: cards,
      ),
    );
  }
}

class _RowLoading extends StatelessWidget {
  const _RowLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Shimmer(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: SpotifyColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        style: const TextStyle(
          color: SpotifyColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({
    required this.message,
    required this.onRetry,
    this.error,
  });

  final String message;
  final VoidCallback onRetry;
  final Object? error;

  bool get _isNetworkError {
    if (error == null) return false;
    if (error is ApiException && (error as ApiException).statusCode == 0) {
      return true;
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('cannot reach server') ||
        lower.contains('waking up') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (error != null && _isNetworkError) ...[
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again. The server may be waking up — wait a moment and retry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else if (error != null && error.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: SpotifyColors.primaryAccent),
            ),
          ),
        ],
      ),
    );
  }
}
