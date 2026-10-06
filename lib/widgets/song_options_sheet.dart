import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/route_transitions.dart';
import 'package:spotify_fy/views/queue_screen.dart';
import 'package:spotify_fy/widgets/add_to_playlist_sheet.dart';

/// "More options" (⋮) bottom sheet for a song. Every row does something
/// real: like, save to playlist, share, or open the queue.
Future<void> showSongOptions(BuildContext context, WidgetRef ref, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SpotifyColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _SongOptionsContent(
      song: song,
      rootContext: context,
      ref: ref,
    ),
  );
}

class _SongOptionsContent extends ConsumerWidget {
  final Song song;
  final BuildContext rootContext;
  final WidgetRef ref;

  const _SongOptionsContent({
    required this.song,
    required this.rootContext,
    required this.ref,
  });

  void _announce(String message) {
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleLike(BuildContext sheetContext, bool isLiked) async {
    final music = ref.read(musicServiceProvider);
    try {
      if (isLiked) {
        await music.unlike(song.videoId);
      } else {
        await music.like(song.videoId);
      }
      ref.invalidate(likedSongsProvider);
      // Keep the player's heart in sync when this is the current song.
      final player = ref.read(playerProvider);
      if (player.currentSong?.videoId == song.videoId &&
          player.isLiked == isLiked) {
        await ref.read(playerProvider.notifier).toggleLike();
      }
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      _announce(isLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs');
    } catch (_) {
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      _announce('Could not update like — are you signed in?');
    }
  }

  Future<void> _share(BuildContext sheetContext) async {
    final text = (song.source == 'youtube' && song.videoId.isNotEmpty)
        ? 'https://youtu.be/${song.videoId}'
        : '${song.title} — ${song.artist}';
    await Clipboard.setData(ClipboardData(text: text));
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    _announce('Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedSongsProvider);
    final isLiked = likedAsync.maybeWhen(
      data: (songs) => songs.any((s) => s.videoId == song.videoId),
      orElse: () => false,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: SpotifyColors.textSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.thumbnailUrl.isEmpty
                    ? Container(
                        width: 48,
                        height: 48,
                        color: SpotifyColors.secondaryBackground,
                        child: const Icon(
                          Icons.music_note,
                          color: SpotifyColors.textSecondary,
                        ),
                      )
                    : Image.network(
                        song.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: SpotifyColors.secondaryBackground,
                          child: const Icon(
                            Icons.music_note,
                            color: SpotifyColors.textSecondary,
                          ),
                        ),
                      ),
              ),
              title: Text(
                song.title,
                style: const TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: SpotifyColors.dividerColor, height: 16),
            _OptionTile(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              iconColor: isLiked ? const Color(0xFFE91E63) : null,
              label: isLiked ? 'Unlike' : 'Like',
              onTap: () => _toggleLike(context, isLiked),
            ),
            _OptionTile(
              icon: Icons.playlist_add,
              label: 'Add to playlist',
              onTap: () {
                Navigator.of(context).pop();
                showAddToPlaylistSheet(rootContext, ref, song);
              },
            ),
            _OptionTile(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () => _share(context),
            ),
            _OptionTile(
              icon: Icons.queue_music,
              label: 'View queue',
              onTap: () {
                Navigator.of(context).pop();
                pushFade(rootContext, const QueueScreen());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? SpotifyColors.textPrimary,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}
