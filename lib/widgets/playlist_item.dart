import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spotify_fy/theme.dart';

class PlaylistItem extends StatelessWidget {
  final String title;
  final String imageUrl;
  final int songCount;
  final VoidCallback? onTap;

  const PlaylistItem({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.songCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: SpotifyColors.cardBackground,
                        child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 48,
                        color: SpotifyColors.cardBackground,
                        child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: SpotifyColors.cardBackground,
                      child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$songCount songs',
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
