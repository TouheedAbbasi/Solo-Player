import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'search.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = LibraryStore.instance;
    final audio = AudioService.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, audio, ShellController.tick]),
        builder: (context, _) {
          final name = Prefs.userName;
          final recent = Prefs.recentAudio
              .map((p) => store.byPath[p])
              .whereType<MediaFile>()
              .take(10)
              .toList();
          final resume = Prefs.recentVideo
              .map((p) => store.byPath[p])
              .whereType<MediaFile>()
              .where((v) {
                final pos = Prefs.position(v.path) ?? 0;
                return pos > 3000 && (v.duration == Duration.zero || pos < v.duration.inMilliseconds - 5000);
              })
              .take(8)
              .toList();
          final MediaFile? now = audio.current ?? (recent.isNotEmpty ? recent.first : null);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: TextStyle(fontSize: 14, color: c.muted)),
                        const SizedBox(height: 2),
                        Text('$name 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text("Let's play something great today.",
                            style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: c.accent,
                    child: Text(
                      name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SearchBarTile(
                hint: 'Search songs, videos, artists…',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
              ),
              SectionHeader(
                title: 'Recently Played',
                action: recent.isEmpty ? null : 'See All',
                onAction: () {
                  ShellController.libraryChip.value = 0;
                  ShellController.tab.value = 2;
                },
              ),
              if (recent.isEmpty)
                Text('Songs you play will show up here.', style: TextStyle(color: c.muted))
              else
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final t = recent[i];
                      return GestureDetector(
                        onTap: () => playSongs(context, recent, i),
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ArtImage(path: t.path, size: 100, radius: 14),
                              const SizedBox(height: 7),
                              Text(t.niceTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Text(t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: c.muted)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.music_note_rounded,
                      title: 'Music',
                      subtitle: '${store.songs.length} songs',
                      onTap: () {
                        ShellController.libraryChip.value = 0;
                        ShellController.tab.value = 2;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickTile(
                      icon: Icons.play_arrow_rounded,
                      title: 'Videos',
                      subtitle: '${store.videos.length} videos',
                      onTap: () => ShellController.tab.value = 1,
                    ),
                  ),
                ],
              ),
              if (now != null) ...[
                SectionHeader(title: 'Continue Listening'),
                _NowCard(track: now, queue: recent.isEmpty ? [now] : recent),
              ],
              if (resume.isNotEmpty) ...[
                const SectionHeader(title: 'Continue Watching'),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: resume.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final v = resume[i];
                      final pos = Prefs.position(v.path) ?? 0;
                      final total = v.duration.inMilliseconds;
                      final progress = total > 0 ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0;
                      return GestureDetector(
                        onTap: () => playVideos(context, resume, i),
                        child: SizedBox(
                          width: 168,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VideoThumb(file: v),
                                      Container(color: Colors.black.withOpacity(0.15)),
                                      const Center(
                                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                      ),
                                      if (progress > 0)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 3,
                                            color: Colors.white,
                                            backgroundColor: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(v.niceTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (store.state == ScanState.ready && store.videos.isEmpty && store.songs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No media found yet',
                    hint: 'Open Settings → Scan report to see what the scan found.',
                  ),
                ),
              if (store.state == ScanState.denied)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Storage permission needed',
                    hint: 'Allow access from the Library tab to see your videos and music.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Icon(icon, color: c.onAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  final MediaFile track;
  final List<MediaFile> queue;
  const _NowCard({required this.track, required this.queue});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = AudioService.instance;
    final isCurrent = a.current?.id == track.id;
    return GestureDetector(
      onTap: () {
        if (isCurrent) {
          openNowPlaying(context);
        } else {
          final i = queue.indexWhere((e) => e.id == track.id);
          playSongs(context, queue, i < 0 ? 0 : i);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            ArtImage(path: track.path, size: 54, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.niceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(track.artist, style: TextStyle(fontSize: 12.5, color: c.muted)),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(
                  isCurrent && a.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: c.onAccent,
                ),
                onPressed: () {
                  if (isCurrent) {
                    a.player.playOrPause();
                  } else {
                    final i = queue.indexWhere((e) => e.id == track.id);
                    playSongs(context, queue, i < 0 ? 0 : i, open: false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
