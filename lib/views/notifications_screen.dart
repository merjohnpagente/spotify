import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';

/// Real notifications inbox fed by fresh releases — no dead bell icon.
/// Tapping a release plays it; items can be dismissed.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(newReleasesProvider);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: releases.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                color: SpotifyColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load notifications',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(newReleasesProvider),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: SpotifyColors.primaryAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (songs) {
          final visible = songs.where((s) => !_dismissed.contains(s.videoId)).toList();
          if (visible.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: SpotifyColors.textSecondary,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "You're all caught up",
                    style: TextStyle(color: SpotifyColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'New releases will show up here',
                    style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: visible.length,
            separatorBuilder: (context, _) => const Divider(
              color: SpotifyColors.dividerColor,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final song = visible[index];
              return Dismissible(
                key: ValueKey(song.videoId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                onDismissed: (_) => setState(() => _dismissed.add(song.videoId)),
                child: _NotificationTile(song: song, queue: visible),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final Song song;
  final List<Song> queue;

  const _NotificationTile({required this.song, required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.thumbnailUrl.isEmpty
            ? Container(
                width: 52,
                height: 52,
                color: SpotifyColors.cardBackground,
                child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary),
              )
            : CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 52,
                  height: 52,
                  color: SpotifyColors.cardBackground,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 52,
                  height: 52,
                  color: SpotifyColors.cardBackground,
                  child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary),
                ),
              ),
      ),
      title: const Text(
        'New music for you',
        style: TextStyle(
          color: SpotifyColors.primaryAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${song.title} • ${song.artist}',
          style: const TextStyle(color: SpotifyColors.textPrimary, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () => playSongAndOpenPlayer(context, ref, song, queue: queue),
    );
  }
}
