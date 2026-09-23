import 'package:flutter/material.dart';

/// Maps bottom-tab indices to their scroll controllers so re-tapping the
/// active tab scrolls that tab back to the top (standard app behavior).
class ScrollRegistry {
  ScrollRegistry._();

  static final Map<int, ScrollController> _controllers = {};

  static void register(int tabIndex, ScrollController controller) {
    _controllers[tabIndex] = controller;
  }

  static void unregister(int tabIndex) {
    _controllers.remove(tabIndex);
  }

  static void scrollToTop(int tabIndex) {
    final controller = _controllers[tabIndex];
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
}
