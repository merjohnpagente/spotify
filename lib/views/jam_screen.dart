import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/providers/player_provider.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/route_transitions.dart';
import 'package:spotify_fy/views/queue_screen.dart';

/// Jam session v1 — share the current queue via an invite code and manage
/// the shared queue together. Real-time sync across devices is v2.
class JamScreen extends ConsumerStatefulWidget {
  const JamScreen({super.key});

  @override
  ConsumerState<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends ConsumerState<JamScreen> {
  static const _codeKey = 'jam_code';
  String? _code;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _code = prefs.getString(_codeKey);
      _active = _code != null;
    });
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _startJam() async {
    final prefs = await SharedPreferences.getInstance();
    final code = _newCode();
    await prefs.setString(_codeKey, code);
    if (!mounted) return;
    setState(() {
      _code = code;
      _active = true;
    });
  }

  Future<void> _endJam() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeKey);
    if (!mounted) return;
    setState(() {
      _code = null;
      _active = false;
    });
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: 'Join my Jam: $_code'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;

    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Jam session',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SpotifyColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: SpotifyColors.primaryAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.groups,
                          color: SpotifyColors.primaryAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _active ? 'Jam active — $_code' : 'Start a Jam',
                        style: const TextStyle(
                          color: SpotifyColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Friends join with your code and you listen from the same queue. '
                  'V1 shares the queue on this device — live sync is next.',
                  style: TextStyle(
                      color: SpotifyColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _active ? _copyCode : _startJam,
                        style: FilledButton.styleFrom(
                          backgroundColor: SpotifyColors.primaryAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text(_active ? 'Copy invite' : 'Start Jam'),
                      ),
                    ),
                    if (_active) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _endJam,
                        child: const Text('End',
                            style: TextStyle(color: SpotifyColors.textSecondary)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Up next (${player.queue.length})',
                style: const TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => pushFade(context, const QueueScreen()),
                child: const Text('Open queue',
                    style: TextStyle(color: SpotifyColors.primaryAccent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (song == null)
            const Text('Play something to start the Jam queue.',
                style: TextStyle(color: SpotifyColors.textSecondary))
          else
            ...player.queue.take(8).map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: s.thumbnailUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => Container(
                            width: 48,
                            height: 48,
                            color: SpotifyColors.cardBackground,
                            child: const Icon(Icons.music_note,
                                color: SpotifyColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: SpotifyColors.textPrimary, fontSize: 14)),
                            Text(s.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: SpotifyColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
