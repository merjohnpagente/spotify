import 'package:flutter/material.dart';

import 'package:spotify_fy/theme.dart';

/// Shared scaffold for the in-app legal documents so Privacy Policy and
/// Terms of Service look like the rest of the app instead of dead buttons.
class _LegalScaffold extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;

  const _LegalScaffold({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        itemCount: sections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'Last updated: October 2026',
                style: TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            );
          }
          final section = sections[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.heading,
                  style: const TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.body,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;

  const _LegalSection(this.heading, this.body);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _LegalSection(
      'What we collect',
      'When you create an account we store your name, email and username. '
      'Inside the app we keep your liked songs, playlists, listening history '
      'and preferences so your library follows you on every device.',
    ),
    _LegalSection(
      'How playback works',
      'Music streams from YouTube. When you press play, the app requests a '
      'stream for that track — basic playback data (the video requested) is '
      'visible to YouTube as with any YouTube client.',
    ),
    _LegalSection(
      'What we never do',
      'We never sell your data, never show third-party ads, and never store '
      'your password in plain text. Passwords are hashed on our servers and '
      'sessions use short-lived tokens kept only on your device.',
    ),
    _LegalSection(
      'Your control',
      'You can clear your listening history, delete playlists and remove '
      'likes at any time from inside the app. Deleting your account removes '
      'your profile and library from our database.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(title: 'Privacy Policy', sections: _sections);
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _sections = [
    _LegalSection(
      'The service',
      'SpotifyFY is a fan-made music player for personal, non-commercial '
      'listening. It plays publicly available YouTube content and is not '
      'affiliated with Spotify AB or YouTube.',
    ),
    _LegalSection(
      'Your account',
      'You are responsible for keeping your login details safe and for '
      'everything done under your account. One account is for one person — '
      'do not share your password.',
    ),
    _LegalSection(
      'Fair use',
      'Do not abuse the service: no automated scraping, no attempts to break '
      'into other accounts, and no uploading content you have no rights to. '
      'We may suspend accounts that harm the service or other listeners.',
    ),
    _LegalSection(
      'Availability',
      'The service runs on free-tier hosting and may occasionally be slow or '
      'unavailable during maintenance. Playback quality depends on your '
      'connection and on source availability.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(title: 'Terms of Service', sections: _sections);
  }
}
