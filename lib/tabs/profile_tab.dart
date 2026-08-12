import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/views/history_screen.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final displayName = user?.displayName ?? 'Guest';
    final email = user?.email ?? 'Not signed in';
    final audioQuality =
        (user?.preferences['audioQuality'] as String?) ?? 'medium';
    final language = (user?.preferences['language'] as String?) ?? 'en';

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        SpotifyColors.primaryAccent.withOpacity(0.8),
                        SpotifyColors.primaryAccent.withOpacity(0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SpotifyColors.primaryAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: user?.avatarUrl != null && (user!.avatarUrl!.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            user.avatarUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.person,
                              color: SpotifyColors.textPrimary,
                              size: 50,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: SpotifyColors.textPrimary,
                          size: 50,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user?.username ?? ''}',
                  style: const TextStyle(
                    color: SpotifyColors.primaryAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStat(user.likedSongsCount, 'Liked'),
                        _buildDivider(),
                        _buildStat(user.totalSongsPlayed, 'Plays'),
                        _buildDivider(),
                        _buildStat(
                          (user.totalListeningSeconds ~/ 3600),
                          'Hours',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Preferences',
            style: TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeColor: SpotifyColors.primaryAccent,
              inactiveThumbColor: SpotifyColors.textSecondary,
              inactiveTrackColor: SpotifyColors.cardBackground,
            ),
          ),
          _buildSettingTile(
            icon: Icons.audiotrack,
            title: 'Audio Quality',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _qualityLabels[audioQuality] ?? audioQuality,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
              ],
            ),
            onTap: () => _pickQuality(context, audioQuality),
          ),
          _buildSettingTile(
            icon: Icons.language,
            title: 'Language',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageLabels[language] ?? language,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
              ],
            ),
            onTap: () => _pickLanguage(context, language),
          ),
          const SizedBox(height: 32),
          const Text(
            'Listening History',
            style: TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.history,
            title: 'Recent Songs',
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'About',
            style: TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Version',
            trailing: const Text(
              '1.0.0',
              style: TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
            onTap: () {},
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickQuality(BuildContext context, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.cardBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Audio Quality',
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final entry in _qualityLabels.entries)
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
    await _savePreference('audioQuality', selected);
  }

  Future<void> _pickLanguage(BuildContext context, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpotifyColors.cardBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Language',
                style: TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final entry in _languageLabels.entries)
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
    await _savePreference('language', selected);
  }

  Future<void> _savePreference(String key, String value) async {
    final current = ref.read(authProvider).user?.preferences ?? const {};
    final updated = Map<String, dynamic>.from(current)..[key] = value;
    await ref.read(authProvider.notifier).updateProfile({
      'preferences': updated,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$key saved as $value')),
      );
    }
  }

  Widget _buildStat(int value, String label) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: SpotifyColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: SpotifyColors.dividerColor,
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: SpotifyColors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: SpotifyColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}