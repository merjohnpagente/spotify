import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/theme.dart';

/// "Save to playlist" bottom sheet: pick one of your playlists or create
/// a new one on the spot. Every action hits the real backend.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SpotifyColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _AddToPlaylistContent(
      song: song,
      rootContext: context,
      ref: ref,
    ),
  );
}

class _AddToPlaylistContent extends StatefulWidget {
  final Song song;
  final BuildContext rootContext;
  final WidgetRef ref;

  const _AddToPlaylistContent({
    required this.song,
    required this.rootContext,
    required this.ref,
  });

  @override
  State<_AddToPlaylistContent> createState() => _AddToPlaylistContentState();
}

class _AddToPlaylistContentState extends State<_AddToPlaylistContent> {
  String? _addingId;
  bool _creating = false;

  WidgetRef get _ref => widget.ref;
  Song get _song => widget.song;

  void _announce(String message) {
    ScaffoldMessenger.of(widget.rootContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addTo(String playlistId, String title) async {
    if (_addingId != null) return;
    setState(() => _addingId = playlistId);
    try {
      await _ref.read(playlistServiceProvider).addSong(playlistId, _song.videoId);
      _ref.invalidate(myPlaylistsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _announce('Added to $title');
    } catch (_) {
      if (!mounted) return;
      setState(() => _addingId = null);
      _announce('Could not add to $title');
    }
  }

  Future<void> _createAndAdd() async {
    if (_creating) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.secondaryBackground,
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
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: const Text(
              'Create',
              style: TextStyle(color: SpotifyColors.primaryAccent),
            ),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      final created = await _ref.read(playlistServiceProvider).create(title: title);
      await _ref.read(playlistServiceProvider).addSong(created.id, _song.videoId);
      _ref.invalidate(myPlaylistsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _announce('Added to $title');
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      _announce('Could not create playlist');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = _ref.watch(myPlaylistsProvider);

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
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Save to playlist',
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: SpotifyColors.secondaryBackground,
                  shape: BoxShape.circle,
                ),
                child: _creating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: SpotifyColors.primaryAccent,
                        ),
                      )
                    : const Icon(Icons.add, color: SpotifyColors.textPrimary),
              ),
              title: const Text(
                'New playlist',
                style: TextStyle(color: SpotifyColors.textPrimary, fontSize: 16),
              ),
              onTap: _creating ? null : _createAndAdd,
            ),
            Flexible(
              child: playlists.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: SpotifyColors.primaryAccent,
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => _ref.invalidate(myPlaylistsProvider),
                    child: const Text(
                      'Could not load playlists — tap to retry',
                      style: TextStyle(color: SpotifyColors.primaryAccent),
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No playlists yet — create your first one above.',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final playlist = list[index];
                      final busy = _addingId == playlist.id;
                      final alreadyIn = playlist.songIds.contains(_song.videoId);
                      return ListTile(
                        leading: _PlaylistThumb(url: playlist.coverImageUrl),
                        title: Text(
                          playlist.title,
                          style: const TextStyle(
                            color: SpotifyColors.textPrimary,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          alreadyIn
                              ? 'Already saved • ${playlist.songIds.length} songs'
                              : '${playlist.songIds.length} songs',
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: SpotifyColors.primaryAccent,
                                ),
                              )
                            : alreadyIn
                                ? const Icon(
                                    Icons.check,
                                    color: SpotifyColors.primaryAccent,
                                  )
                                : null,
                        onTap: (busy || alreadyIn)
                            ? null
                            : () => _addTo(playlist.id, playlist.title),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistThumb extends StatelessWidget {
  final String? url;

  const _PlaylistThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: SpotifyColors.secondaryBackground,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.queue_music, color: SpotifyColors.textSecondary),
      );
    }
    return ClipOval(
      child: Image.network(
        url!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 48,
          height: 48,
          color: SpotifyColors.secondaryBackground,
          child: const Icon(Icons.queue_music, color: SpotifyColors.textSecondary),
        ),
      ),
    );
  }
}
