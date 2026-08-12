import 'package:flutter/material.dart';
import 'package:spotify_fy/theme.dart';

class SignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool loading;

  const SignInButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SpotifyColors.primaryAccent,
          disabledBackgroundColor: SpotifyColors.primaryAccent.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: SpotifyColors.textPrimary,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}