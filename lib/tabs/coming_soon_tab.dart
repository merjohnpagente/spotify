import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/scroll_registry.dart';

/// A teaser tab showcasing features that are planned but not built yet.
class ComingSoonTab extends ConsumerStatefulWidget {
  const ComingSoonTab({super.key});

  @override
  ConsumerState<ComingSoonTab> createState() => _ComingSoonTabState();
}

class _ComingSoonTabState extends ConsumerState<ComingSoonTab> {
  final ScrollController _scrollController = ScrollController();

  static const List<_TeaserFeature> _features = [
    _TeaserFeature(
      icon: Icons.podcasts,
      title: 'Podcasts',
      description: 'Shows and episodes picked for you.',
    ),
    _TeaserFeature(
      icon: Icons.lyrics,
      title: 'Lyrics',
      description: 'Real-time synced lyrics on every track.',
    ),
    _TeaserFeature(
      icon: Icons.auto_awesome,
      title: 'AI DJ',
      description: 'A personal DJ that builds your perfect mix.',
    ),
    _TeaserFeature(
      icon: Icons.download_for_offline,
      title: 'Offline mode',
      description: 'Keep listening even without a connection.',
    ),
    _TeaserFeature(
      icon: Icons.surround_sound,
      title: 'Spatial audio',
      description: 'Immersive 3D sound on supported devices.',
    ),
    _TeaserFeature(
      icon: Icons.groups,
      title: 'Jam sessions',
      description: 'Listen together with friends in real time.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    ScrollRegistry.register(4, _scrollController);
  }

  @override
  void dispose() {
    ScrollRegistry.unregister(4);
    _scrollController.dispose();
    super.dispose();
  }

  void _notifyMe() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("You'll be notified!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Coming soon',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          const Text(
            'New features are on the way — stay tuned.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 200,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _features.length,
            itemBuilder: (context, index) => _buildFeatureCard(_features[index]),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _notifyMe,
            style: FilledButton.styleFrom(
              backgroundColor: SpotifyColors.primaryAccent,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Notify me',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_TeaserFeature feature) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpotifyColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SpotifyColors.primaryAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              size: 22,
              color: SpotifyColors.primaryAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feature.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feature.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SpotifyColors.primaryAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: SpotifyColors.primaryAccent.withValues(alpha: 0.45),
              ),
            ),
            child: const Text(
              'Coming soon',
              style: TextStyle(
                color: SpotifyColors.primaryAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaserFeature {
  const _TeaserFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
