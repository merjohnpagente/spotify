import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/route_transitions.dart';
import 'package:spotify_fy/utils/scroll_registry.dart';
import 'package:spotify_fy/views/audio_effects_screen.dart';
import 'package:spotify_fy/views/dj_mix_screen.dart';
import 'package:spotify_fy/views/downloads_screen.dart';
import 'package:spotify_fy/views/jam_screen.dart';
import 'package:spotify_fy/views/podcasts_screen.dart';

/// Extras tab — five fully functional sections. No more dead teasers.
class ExtrasTab extends ConsumerStatefulWidget {
  const ExtrasTab({super.key});

  @override
  ConsumerState<ExtrasTab> createState() => _ExtrasTabState();
}

class _ExtrasTabState extends ConsumerState<ExtrasTab> {
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final features = [
      _ExtraFeature(
        icon: Icons.podcasts,
        title: 'Podcasts',
        description: 'Shows and episodes picked for you.',
        badge: 'Listen now',
        onTap: () => pushFade(context, const PodcastsScreen()),
      ),
      _ExtraFeature(
        icon: Icons.auto_awesome,
        title: 'Smart Mix',
        description: 'A personal mix from your taste.',
        badge: 'Play now',
        onTap: () => pushFade(context, const DjMixScreen()),
      ),
      _ExtraFeature(
        icon: Icons.download_for_offline,
        title: 'Offline',
        description: 'Storage, cache and offline prefs.',
        badge: 'Manage',
        onTap: () => pushFade(context, const DownloadsScreen()),
      ),
      _ExtraFeature(
        icon: Icons.surround_sound,
        title: 'Audio effects',
        description: 'Volume, presets and spatial.',
        badge: 'Tune',
        onTap: () => pushFade(context, const AudioEffectsScreen()),
      ),
      _ExtraFeature(
        icon: Icons.groups,
        title: 'Jam',
        description: 'Listen together with friends.',
        badge: 'Start Jam',
        onTap: () => pushFade(context, const JamScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Extras',
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
            'More ways to listen — all working.',
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
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _buildFeatureCard(feature);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_ExtraFeature feature) {
    return Semantics(
      button: true,
      label: '${feature.title}: ${feature.description}',
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                child: Text(
                  feature.badge,
                  style: const TextStyle(
                    color: SpotifyColors.primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraFeature {
  const _ExtraFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onTap;
}
