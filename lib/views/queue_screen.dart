import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/theme.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SpotifyColors.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Queue',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (player.queue.isNotEmpty)
            TextButton(
              onPressed: () {
                controller.clearQueue();
                Navigator.pop(context);
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
            ),
        ],
      ),
      body: player.queue.isEmpty
          ? const Center(
              child: Text(
                'Your queue is empty',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: player.queue.length,
              buildDefaultDragHandles: false,
              onReorder: (from, to) {
                final target = to > from ? to - 1 : to;
                controller.moveQueueItem(from, target);
              },
              itemBuilder: (context, index) {
                final song = player.queue[index];
                final isCurrent = index == player.currentIndex;
                return _QueueTile(
                  key: ValueKey(song.videoId + index.toString()),
                  index: index,
                  title: song.title,
                  artist: song.artist,
                  imageUrl: song.thumbnailUrl,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && player.isPlaying && !player.loading,
                  onTap: () => controller.playAt(index),
                  onRemove: () => controller.removeFromQueue(index),
                );
              },
            ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final int index;
  final String title;
  final String artist;
  final String imageUrl;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _QueueTile({
    required Key key,
    required this.index,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.isCurrent = false,
    this.isPlaying = false,
    this.onTap,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? SpotifyColors.cardBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.drag_handle,
                color: SpotifyColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 48,
                height: 48,
                color: SpotifyColors.cardBackground,
                child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isCurrent ? SpotifyColors.primaryAccent : SpotifyColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (isPlaying)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SpotifyColors.primaryAccent,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: SpotifyColors.textSecondary, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
