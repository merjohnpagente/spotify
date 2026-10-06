import 'package:flutter/material.dart';

/// Clean monochrome "G" mark for the "Continue with Google" button.
/// Matches the app's dark Spotify-style theme (white glyphs).
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.85,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
