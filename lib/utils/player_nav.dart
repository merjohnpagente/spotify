import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/views/player_screen.dart';

void playSongAndOpenPlayer(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  List<Song>? queue,
}) {
  final songs = queue ?? [song];
  final index = songs.indexWhere((s) => s.videoId == song.videoId);
  ref.read(playerProvider.notifier).playQueue(songs, index: index < 0 ? 0 : index);

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
