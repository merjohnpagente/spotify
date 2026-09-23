import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spotify_fy/theme.dart';

class SearchResultCard extends StatelessWidget {
  final String title;
  final String artist;
  final String imageUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;
  final bool isPreview;

  const SearchResultCard({
    super.key,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.onPlay,
    this.onTap,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 56,
                  height: 56,
                  color: SpotifyColors.cardBackground,
                  child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 56,
                  height: 56,
                  color: SpotifyColors.cardBackground,
                  child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
                    artist,
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isPreview)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PREVIEW 30s',
                        style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPlay,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: SpotifyColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: SpotifyColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
