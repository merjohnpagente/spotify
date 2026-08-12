import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/playlist.dart';
import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/playlist_service.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/views/liked_songs_screen.dart';
import 'package:spotify_fy/views/playlist_detail_screen.dart';
import 'package:spotify_fy/widgets/library_item.dart';
import 'package:spotify_fy/widgets/playlist_item.dart';

class LibraryTab extends ConsumerWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(likedSongsProvider);
    final playlists = ref.watch(myPlaylistsProvider);
    final playlistService = ref.watch(playlistServiceProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Library',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: SpotifyColors.textPrimary, size: 28),
            onPressed: () => _createPlaylist(context, ref, playlistService),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(likedSongsProvider);
          ref.invalidate(myPlaylistsProvider);
        },
        color: SpotifyColors.primaryAccent,
        backgroundColor: SpotifyColors.cardBackground,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            LibraryItem(
              icon: Icons.favorite,
              title: 'Liked Songs',
              subtitle: liked.maybeWhen(
                data: (songs) => '${songs.length} songs',
                orElse: () => 'Songs',
              ),
              iconColor: const Color(0xFFE91E63),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LikedSongsScreen()),
                );
              },
            ),
            LibraryItem(
              icon: Icons.download,
              title: 'Downloaded',
              subtitle: 'Offline playback',
              iconColor: SpotifyColors.primaryAccent,
              onTap: () {},
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Playlists',
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            playlists.when(
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No playlists yet. Tap + to create one.',
                        style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final playlist = list[index];
                        return PlaylistItem(
                          title: playlist.title,
                          imageUrl: playlist.coverImageUrl ?? '',
                          songCount: playlist.songs.isNotEmpty
                              ? playlist.songs.length
                              : playlist.songIds.length,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PlaylistDetailScreen(playlistId: playlist.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Text(
                      'Could not load playlists',
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(myPlaylistsProvider),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: SpotifyColors.primaryAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createPlaylist(BuildContext context, WidgetRef ref, PlaylistService service) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.cardBackground,
        title: const Text(
          'New Playlist',
          style: TextStyle(color: SpotifyColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SpotifyColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: SpotifyColors.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: SpotifyColors.dividerColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: SpotifyColors.primaryAccent),
            ),
          ),
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
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(context);
              try {
                await service.create(title: title);
                ref.invalidate(myPlaylistsProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not create playlist')),
                  );
                }
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: SpotifyColors.primaryAccent),
            ),
          ),
        ],
      ),
    );
  }
}