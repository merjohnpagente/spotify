import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:spotify_fy/theme.dart';

class SongCard extends StatefulWidget {
  final String title;
  final String artist;
  final String imageUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;
  final bool isPreview;

  const SongCard({
    super.key,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.onPlay,
    this.onTap,
    this.isPreview = false,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (hovering) {
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 160,
                        height: 160,
                        color: SpotifyColors.cardBackground,
                        child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 48),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 160,
                        height: 160,
                        color: SpotifyColors.cardBackground,
                        child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 48),
                      ),
                    ),
                  ),
                  // Play button: always visible on mobile, hover-revealed on desktop with scale
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        onTap: widget.onPlay,
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: SpotifyColors.primaryAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: SpotifyColors.primaryAccent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: SpotifyColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Subtle gradient overlay for better play button contrast
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.artist,
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.isPreview)
                Container(
                  margin: const EdgeInsets.only(top: 4),
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
      ),
    );
  }
}
