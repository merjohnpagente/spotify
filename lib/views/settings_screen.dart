import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/version.dart';
import 'package:spotify_fy/views/stats_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const Map<String, String> _qualityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };

  static const Map<String, String> _languageLabels = {
    'en': 'English',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    ref.read(sharedPreferencesProvider.future).then((prefs) {
      if (mounted) {
        setState(() => _notifications = prefs.getBool('notifications') ?? true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final audioQuality = (user?.preferences['audioQuality'] as String?) ?? 'medium';
    final language = (user?.preferences['language'] as String?) ?? 'en';

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: user != null ? user.displayName : 'Guest',
            onTap: () => _editProfile(context),
          ),
          const SizedBox(height: 24),
          const Text(
            'Playback',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.audiotrack,
            title: 'Audio Quality',
            subtitle: _qualityLabels[audioQuality] ?? audioQuality,
            onTap: () => _pickOption(
              context,
              title: 'Audio Quality',
              options: _qualityLabels,
              current: audioQuality,
              onSelected: (value) => _savePreference('audioQuality', value),
            ),
          ),
          _SettingTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _languageLabels[language] ?? language,
            onTap: () => _pickOption(
              context,
              title: 'Language',
              options: _languageLabels,
              current: language,
              onSelected: (value) => _savePreference('language', value),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined, color: SpotifyColors.textPrimary),
            title: const Text(
              'Notifications',
              style: TextStyle(color: SpotifyColors.textPrimary, fontSize: 16),
            ),
            subtitle: const Text(
              'Now playing & new releases',
              style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12),
            ),
            value: _notifications,
            activeThumbColor: SpotifyColors.primaryAccent,
            onChanged: (value) async {
              setState(() => _notifications = value);
              final prefs = await ref.read(sharedPreferencesProvider.future);
              await prefs.setBool('notifications', value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Data',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.insights_outlined,
            title: 'Listening Stats',
            subtitle: 'Genres, artists & top songs',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'About',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '${AppVersion.version} (${AppVersion.buildNumber})',
          ),
          _SettingTile(
            icon: Icons.favorite_outline,
            title: 'Made with YouTube',
            subtitle: 'Ad-free music powered by yt-dlp',
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.displayName);
    final bioCtrl = TextEditingController(text: user.bio);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyColors.cardBackground,
        title: const Text('Edit Profile', style: TextStyle(color: SpotifyColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: SpotifyColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Display name',
                labelStyle: TextStyle(color: SpotifyColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.dividerColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.primaryAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: SpotifyColors.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: SpotifyColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.dividerColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.primaryAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: SpotifyColors.primaryAccent)),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final parts = nameCtrl.text.trim().split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    await ref.read(authProvider.notifier).updateProfile({
      'firstName': first,
      'lastName': last,
      'bio': bioCtrl.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Future<void> _pickOption(
    BuildContext context, {
    required String title,
    required Map<String, String> options,
    required String current,
    required void Function(String) onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.cardBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final entry in options.entries)
              ListTile(
                title: Text(
                  entry.value,
                  style: const TextStyle(color: SpotifyColors.textPrimary),
                ),
                trailing: entry.key == current
                    ? const Icon(Icons.check, color: SpotifyColors.primaryAccent)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    onSelected(selected);
  }

  Future<void> _savePreference(String key, String value) async {
    final current = ref.read(authProvider).user?.preferences ?? const {};
    final updated = Map<String, dynamic>.from(current)..[key] = value;
    await ref.read(authProvider.notifier).updateProfile({'preferences': updated});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$key saved')),
      );
    }
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: SpotifyColors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
