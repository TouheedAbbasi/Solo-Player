import 'dart:io';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/playlists.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'queue.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final AudioService _a = AudioService.instance;
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  void _sleepSheet() {
    final c = AppColors.of(context);
    const options = <MapEntry<String, Duration?>>[
      MapEntry('Off', null),
      MapEntry('15 minutes', Duration(minutes: 15)),
      MapEntry('30 minutes', Duration(minutes: 30)),
      MapEntry('45 minutes', Duration(minutes: 45)),
      MapEntry('1 hour', Duration(hours: 1)),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sleep timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.key),
                onTap: () {
                  Navigator.pop(sheet);
                  _a.setSleep(o.value);
                  if (o.value != null) toast(context, 'Music will stop in ${o.key}');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _loadLyrics(String path) async {
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return null;
    final base = path.substring(0, dot);
    for (final e in const ['lrc', 'txt']) {
      try {
        final f = File('$base.$e');
        if (await f.exists()) {
          final raw = await f.readAsString();
          return raw.replaceAll(RegExp(r'\[[0-9:.]+\]'), '').trim();
        }
      } catch (_) {}
    }
    return null;
  }

  void _lyrics(MediaFile t) {
    final c = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lyrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<String?>(
                  future: _loadLyrics(t.path),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final text = snap.data;
                    if (text == null || text.isEmpty) {
                      return Text(
                        'No lyrics found.\n\nPut a .lrc or .txt file with the same name as the song in the same folder and it will show up here.',
                        style: TextStyle(color: c.muted, height: 1.5),
                      );
                    }
                    return SingleChildScrollView(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.7)));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_a, PlaylistStore.instance]),
      builder: (context, _) {
        final t = _a.current;
        if (t == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold();
        }
        final fav = PlaylistStore.instance.isFav(t.path);
        final art = (MediaQuery.of(context).size.width * 0.74).clamp(200.0, 320.0).toDouble();
        final repeatIcon = _a.repeat == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: fav ? Colors.redAccent : c.text),
                onPressed: () => PlaylistStore.instance.toggleFav(t.path),
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const QueueScreen())),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  if (v == 'sleep') _sleepSheet();
                  if (v == 'playlist') showAddToPlaylist(context, [t.path]);
                  if (v == 'info') showInfo(context, t);
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'sleep',
                    child: Text(_a.sleepEnd != null ? 'Sleep timer (on)' : 'Sleep timer'),
                  ),
                  const PopupMenuItem<String>(value: 'playlist', child: Text('Add to playlist')),
                  const PopupMenuItem<String>(value: 'info', child: Text('Properties')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ArtImage(path: t.path, size: art, radius: 28),
                  ),
                  const SizedBox(height: 26),
                  Text(t.niceTitle,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(t.artist, style: TextStyle(fontSize: 14.5, color: c.muted)),
                  const SizedBox(height: 22),
                  _waveform(t),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 26,
                        icon: Icon(Icons.shuffle_rounded, color: _a.shuffle ? c.accent : c.muted),
                        onPressed: _a.toggleShuffle,
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: _a.previous,
                      ),
                      Container(
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                        child: IconButton(
                          iconSize: 42,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            _a.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: c.onAccent,
                          ),
                          onPressed: () => _a.player.playOrPause(),
                        ),
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: () => _a.next(),
                      ),
                      IconButton(
                        iconSize: 26,
                        icon: Icon(repeatIcon, color: _a.repeat == 0 ? c.muted : c.accent),
                        onPressed: _a.cycleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _action(Icons.lyrics_outlined, 'Lyrics', () => _lyrics(t)),
                      _action(Icons.speed_rounded, '${_a.speed}x', () {
                        final i = _speeds.indexOf(_a.speed);
                        _a.setSpeed(_speeds[(i + 1) % _speeds.length]);
                      }),
                      _action(Icons.playlist_add_rounded, 'Add to Playlist',
                          () => showAddToPlaylist(context, [t.path])),
                      _action(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, 'Favorite',
                          () => PlaylistStore.instance.toggleFav(t.path),
                          color: fav ? Colors.redAccent : null),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Icon(icon, size: 24, color: color ?? c.text),
            const SizedBox(height: 5),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _waveform(MediaFile t) {
    final c = AppColors.of(context);
    return StreamBuilder<Duration>(
      stream: _a.player.stream.duration,
      initialData: _a.player.state.duration,
      builder: (context, ds) {
        final dur = ds.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _a.player.stream.position,
          initialData: _a.player.state.position,
          builder: (context, ps) {
            final pos = ps.data ?? Duration.zero;
            final total = dur.inMilliseconds;
            final progress = total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0).toDouble() : 0.0;
            return Column(
              children: [
                WaveformSeek(
                  seed: t.path,
                  progress: progress,
                  onSeek: (f) => _a.player.seek(Duration(milliseconds: (f * total).round())),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmtDur(pos), style: TextStyle(fontSize: 12.5, color: c.muted)),
                    Text(fmtDur(dur), style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
