import 'package:flutter/material.dart';
import 'package:spotify_fy/theme.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData icon;

  const SocialButton({super.key, required this.onPressed, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: SpotifyColors.textSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: SpotifyColors.textSecondary, size: 24),
            const SizedBox(width: 16),
            Text(
              text,
              style: const TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}