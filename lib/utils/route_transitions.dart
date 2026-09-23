import 'package:flutter/material.dart';

/// Consistent fade-and-slide-up route transition for secondary screens.
///
/// The full-screen player uses its own slide-up transition; every other
/// pushed route (Liked Songs, History, Settings, Playlists, ...) should
/// go through [pushFade] so navigation feels uniform.
PageRoute<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 280)}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Pushes [page] with the shared fade transition.
void pushFade<T extends Object?>(BuildContext context, Widget page) {
  Navigator.push<T>(context, fadeRoute<T>(page));
}
