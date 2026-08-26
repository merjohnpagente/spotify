import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/services/update_service.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/version.dart';
import 'package:spotify_fy/tabs/home_tab.dart';
import 'package:spotify_fy/tabs/search_tab.dart';
import 'package:spotify_fy/tabs/library_tab.dart';
import 'package:spotify_fy/tabs/profile_tab.dart';
import 'package:spotify_fy/views/player_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _miniPlayerController;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _tabs = const [
    HomeTab(),
    SearchTab(),
    LibraryTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _miniPlayerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _miniPlayerController, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _miniPlayerController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Prompts installed-app users when a newer APK is published.
  /// Skipped on web - there, updating is just refreshing the page.
  Future<void> _checkForUpdate() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }
    try {
      final info = await UpdateService().checkForUpdate();
      if (info == null || !mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: SpotifyColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Update available',
            style: TextStyle(color: SpotifyColors.textPrimary),
          ),
          content: Text(
            'Version ${info.latestVersion} is available (you have ${AppVersion.version}).'
            '${info.message == null ? '' : '\n\n${info.message}'}',
            style: const TextStyle(color: SpotifyColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: SpotifyColors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpotifyColors.primaryAccent,
              ),
              onPressed: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(info.apkUrl), mode: LaunchMode.externalApplication);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Never block the app because the update check failed.
    }
  }

  void _openFullPlayer() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final showMiniPlayer = player.currentSong != null;

    if (showMiniPlayer && !_miniPlayerController.isAnimating) {
      _miniPlayerController.forward();
    }

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      body: Stack(
        children: [
          _tabs[_currentIndex],
          if (showMiniPlayer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildMiniPlayer(player),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: SpotifyColors.primaryBackground,
        selectedItemColor: SpotifyColors.primaryAccent,
        unselectedItemColor: SpotifyColors.textSecondary,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search, size: 24),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music, size: 24),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 24),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(PlayerState player) {
    final controller = ref.read(playerProvider.notifier);
    final song = player.currentSong!;

    return GestureDetector(
      onTap: _openFullPlayer,
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: SpotifyColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                song.thumbnailUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  color: SpotifyColors.cardBackground,
                  child: const Icon(Icons.music_note, color: SpotifyColors.textSecondary, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: SpotifyColors.textPrimary, size: 24),
                  onPressed: controller.previous,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: controller.togglePlayPause,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SpotifyColors.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                    child: player.loading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SpotifyColors.textPrimary,
                            ),
                          )
                        : Icon(
                            player.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: SpotifyColors.textPrimary,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: SpotifyColors.textPrimary, size: 24),
                  onPressed: controller.next,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
