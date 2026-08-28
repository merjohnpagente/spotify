import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/views/queue_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isDragging = false;
  double _dragPosition = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncRotation(bool playing) {
    if (playing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);
    final song = player.currentSong;
    final playing = player.isPlaying && !player.loading;

    _syncRotation(playing);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: SpotifyColors.primaryBackground,
                elevation: 0,
                pinned: false,
                floating: true,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: SpotifyColors.textPrimary, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: SpotifyColors.textPrimary, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * 3.14159,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: SpotifyColors.primaryAccent.withOpacity(playing ? 0.4 : 0.1),
                                blurRadius: playing ? 40 : 10,
                                spreadRadius: playing ? 10 : 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: song != null
                                ? Image.network(
                                    song.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildArtworkFallback(),
                                  )
                                : _buildArtworkFallback(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        song?.title ?? 'Nothing playing',
                        style: const TextStyle(
                          color: SpotifyColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song != null
                            ? '${song.artist}${song.album.isNotEmpty ? ' • ${song.album}' : ''}'
                            : 'Select a song to start listening',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: player.currentSong == null ? null : controller.toggleLike,
                            child: AnimatedScale(
                              scale: player.isLiked ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                player.isLiked ? Icons.favorite : Icons.favorite_border,
                                color: player.isLiked ? const Color(0xFFE91E63) : SpotifyColors.textSecondary,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: SpotifyColors.primaryAccent,
                              inactiveTrackColor: SpotifyColors.dividerColor,
                              thumbColor: SpotifyColors.primaryAccent,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayColor: SpotifyColors.primaryAccent.withOpacity(0.2),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            ),
                            child: Slider(
                              value: _sliderValue(player),
                              min: 0,
                              max: player.duration.inMilliseconds > 0
                                  ? player.duration.inMilliseconds.toDouble()
                                  : 1,
                              onChangeStart: (_) {
                                setState(() {
                                  _isDragging = true;
                                  _dragPosition = _sliderValue(player);
                                });
                              },
                              onChanged: (value) {
                                setState(() {
                                  _dragPosition = value;
                                });
                              },
                              onChangeEnd: (value) {
                                controller.seek(Duration(milliseconds: value.round()));
                                setState(() {
                                  _isDragging = false;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatTime(_isDragging
                                      ? Duration(milliseconds: _dragPosition.round())
                                      : player.position),
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatTime(player.duration),
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (player.loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(
                            color: SpotifyColors.primaryAccent,
                            backgroundColor: SpotifyColors.cardBackground,
                          ),
                        ),
                      if (player.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            player.error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: Icons.shuffle,
                            isActive: player.shuffle,
                            onTap: controller.toggleShuffle,
                            size: 24,
                          ),
                          _buildControlButton(
                            icon: Icons.skip_previous,
                            isActive: false,
                            onTap: player.currentSong == null ? null : controller.previous,
                            size: 28,
                            background: true,
                          ),
                          _buildPlayPauseButton(player, controller),
                          _buildControlButton(
                            icon: Icons.skip_next,
                            isActive: false,
                            onTap: player.currentSong == null ? null : controller.next,
                            size: 28,
                            background: true,
                          ),
                          _buildControlButton(
                            icon: player.repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                            isActive: player.repeatMode != RepeatMode.off,
                            onTap: controller.toggleRepeat,
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Icon(Icons.volume_down, color: SpotifyColors.textSecondary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                activeTrackColor: SpotifyColors.primaryAccent,
                                inactiveTrackColor: SpotifyColors.dividerColor,
                                thumbColor: SpotifyColors.primaryAccent,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayColor: SpotifyColors.primaryAccent.withOpacity(0.2),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                              ),
                              child: Slider(
                                value: player.volume,
                                min: 0,
                                max: 1,
                                onChanged: controller.setVolume,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.volume_up, color: SpotifyColors.textSecondary, size: 24),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBottomActionButton(Icons.devices, 'Devices'),
                          _buildBottomActionButton(Icons.share, 'Share'),
                          _buildBottomActionButton(Icons.lyrics, 'Lyrics'),
                          _buildBottomActionButton(
                            Icons.queue_music,
                            'Queue',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const QueueScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _sliderValue(PlayerState player) {
    if (player.duration.inMilliseconds == 0) return 0;
    final value = player.position.inMilliseconds.toDouble();
    return value.clamp(0, player.duration.inMilliseconds.toDouble());
  }

  Widget _buildArtworkFallback() {
    return Container(
      color: SpotifyColors.cardBackground,
      child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 80),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback? onTap,
    required double size,
    bool background = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: background ? 56 : 48,
        height: background ? 56 : 48,
        decoration: background
            ? BoxDecoration(
                color: SpotifyColors.cardBackground,
                shape: BoxShape.circle,
              )
            : null,
        child: Icon(
          icon,
          color: isActive ? SpotifyColors.primaryAccent : SpotifyColors.textPrimary,
          size: size,
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(PlayerState player, PlayerController controller) {
    return GestureDetector(
      onTap: player.currentSong == null ? null : controller.togglePlayPause,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: SpotifyColors.primaryAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SpotifyColors.primaryAccent.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          player.isPlaying ? Icons.pause : Icons.play_arrow,
          color: SpotifyColors.textPrimary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildBottomActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SpotifyColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SpotifyColors.textPrimary, size: 24),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: SpotifyColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
      ),
    );
  }
}
