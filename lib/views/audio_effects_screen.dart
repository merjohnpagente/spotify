import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/theme.dart';

/// Audio effects — real volume control + persisted EQ presets.
/// True system-wide EQ/spatial needs platform DSP; presets are stored and
/// applied as listening preferences, volume drives the player directly.
class AudioEffectsScreen extends ConsumerStatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  ConsumerState<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends ConsumerState<AudioEffectsScreen> {
  static const _presetKey = 'audio_preset';
  static const _spatialKey = 'spatial_enabled';
  static const _monoKey = 'mono_enabled';

  static const List<String> _presets = ['Flat', 'Bass Boost', 'Pop', 'Rock', 'Vocal', 'Treble'];

  String _preset = 'Flat';
  bool _spatial = false;
  bool _mono = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _preset = prefs.getString(_presetKey) ?? 'Flat';
      _spatial = prefs.getBool(_spatialKey) ?? false;
      _mono = prefs.getBool(_monoKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _savePreset(String value) async {
    setState(() => _preset = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, value);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Preset: $value')));
    }
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Audio effects',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const Text(
                  'Volume',
                  style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.volume_down, color: SpotifyColors.textSecondary),
                    Expanded(
                      child: Slider(
                        value: player.volume,
                        min: 0,
                        max: 1,
                        activeColor: SpotifyColors.primaryAccent,
                        onChanged: controller.setVolume,
                      ),
                    ),
                    const Icon(Icons.volume_up, color: SpotifyColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Equalizer preset',
                  style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets
                      .map((p) => ChoiceChip(
                            label: Text(p),
                            selected: _preset == p,
                            selectedColor: SpotifyColors.primaryAccent,
                            backgroundColor: SpotifyColors.cardBackground,
                            labelStyle: TextStyle(
                              color: _preset == p
                                  ? Colors.white
                                  : SpotifyColors.textSecondary,
                            ),
                            onSelected: (_) => _savePreset(p),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _spatial,
                  onChanged: (v) {
                    setState(() => _spatial = v);
                    _saveToggle(_spatialKey, v);
                  },
                  title: const Text('Spatial audio',
                      style: TextStyle(color: SpotifyColors.textPrimary)),
                  subtitle: const Text(
                      'Wider stereo image on supported devices',
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13)),
                  activeThumbColor: SpotifyColors.primaryAccent,
                ),
                SwitchListTile(
                  value: _mono,
                  onChanged: (v) {
                    setState(() => _mono = v);
                    _saveToggle(_monoKey, v);
                  },
                  title: const Text('Mono audio',
                      style: TextStyle(color: SpotifyColors.textPrimary)),
                  subtitle: const Text('Combine left and right channels',
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13)),
                  activeThumbColor: SpotifyColors.primaryAccent,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: presets and spatial toggles are saved on this device. '
                  'Full hardware EQ needs platform DSP — this screen keeps '
                  'your preferences and drives player volume directly.',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ],
            ),
    );
  }
}
