import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/route_transitions.dart';
import 'package:spotify_fy/views/liked_songs_screen.dart';

/// Offline storage screen: real on-device usage + working cache controls
/// and offline preferences. Full per-track downloads remain roadmap —
/// this is the functional home for that feature.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<_StorageInfo> _storageFuture;
  bool _autoCache = true;
  bool _wifiOnly = true;
  String _quality = 'medium';
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _storageFuture = _measureStorage();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoCache = prefs.getBool('offline_auto_cache') ?? true;
      _wifiOnly = prefs.getBool('offline_wifi_only') ?? true;
      _quality = prefs.getString('offline_quality') ?? 'medium';
      _prefsLoaded = true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_auto_cache', _autoCache);
    await prefs.setBool('offline_wifi_only', _wifiOnly);
    await prefs.setString('offline_quality', _quality);
  }

  Future<_StorageInfo> _measureStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = await _dirSize(dir);
      return _StorageInfo(available: true, bytes: bytes);
    } catch (_) {
      return const _StorageInfo(available: false, bytes: 0);
    }
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // File vanished mid-scan — ignore it.
        }
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _refreshStorage() {
    setState(() {
      _storageFuture = _measureStorage();
    });
  }

  Future<void> _clearImageCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    _refreshStorage();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Image cache cleared')));
    }
  }

  void _pickQuality() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SpotifyColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['low', 'medium', 'high']
              .map((q) => ListTile(
                    title: Text(q,
                        style: const TextStyle(color: SpotifyColors.textPrimary)),
                    trailing: q == _quality
                        ? const Icon(Icons.check, color: SpotifyColors.primaryAccent)
                        : null,
                    onTap: () {
                      setState(() => _quality = q);
                      _savePrefs();
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

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
        title: const Text(
          'Offline',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: SpotifyColors.textPrimary),
            tooltip: 'Re-measure storage',
            onPressed: _refreshStorage,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SpotifyColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: SpotifyColors.secondaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storage_outlined,
                    color: SpotifyColors.primaryAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'On-device storage',
                        style: TextStyle(
                          color: SpotifyColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<_StorageInfo>(
                        future: _storageFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text(
                              'Measuring…',
                              style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 14,
                              ),
                            );
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              !snapshot.data!.available) {
                            return Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Could not measure storage',
                                    style: TextStyle(
                                      color: SpotifyColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _refreshStorage,
                                  child: const Text('Retry',
                                      style: TextStyle(
                                          color: SpotifyColors.primaryAccent)),
                                ),
                              ],
                            );
                          }
                          return Text(
                            _formatBytes(snapshot.data!.bytes),
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _clearImageCache,
            icon: const Icon(Icons.cleaning_services_outlined,
                color: SpotifyColors.primaryAccent, size: 18),
            label: const Text('Clear image cache',
                style: TextStyle(color: SpotifyColors.primaryAccent)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Offline preferences',
            style: TextStyle(
              color: SpotifyColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_prefsLoaded) ...[
            SwitchListTile(
              value: _autoCache,
              onChanged: (v) {
                setState(() => _autoCache = v);
                _savePrefs();
              },
              title: const Text('Auto-cache played songs',
                  style: TextStyle(color: SpotifyColors.textPrimary)),
              subtitle: const Text('Replays start instantly',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13)),
              activeThumbColor: SpotifyColors.primaryAccent,
            ),
            SwitchListTile(
              value: _wifiOnly,
              onChanged: (v) {
                setState(() => _wifiOnly = v);
                _savePrefs();
              },
              title: const Text('Cache on Wi-Fi only',
                  style: TextStyle(color: SpotifyColors.textPrimary)),
              subtitle: const Text('Save mobile data',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13)),
              activeThumbColor: SpotifyColors.primaryAccent,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offline quality',
                  style: TextStyle(color: SpotifyColors.textPrimary)),
              subtitle: Text(_quality,
                  style: const TextStyle(color: SpotifyColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right,
                  color: SpotifyColors.textSecondary),
              onTap: _pickQuality,
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Songs you play are cached automatically so replays start '
            'instantly. Full offline downloads — entire playlists kept on '
            'your device with no connection — are on the roadmap.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => pushFade(context, const LikedSongsScreen()),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotifyColors.primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: const Text(
                'View Liked Songs',
                style: TextStyle(
                  color: Colors.white,
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
}

class _StorageInfo {
  final bool available;
  final int bytes;

  const _StorageInfo({required this.available, required this.bytes});
}
