import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/watch.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';
import 'nav.dart';
import 'search.dart';
import 'series.dart';
import '../core/strings.dart';

class VideosTab extends StatefulWidget {
  const VideosTab({super.key});

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  static const List<String> _labels = ['Folders', 'All', 'Recently Added', 'In Progress'];
  int _chip = Prefs.videoView == 1 ? 1 : 0;
  int _folderSort = Prefs.folderSort;
  final Set<String> _sel = <String>{};
  bool get _selecting => _sel.isNotEmpty;

  List<MediaFile> _filtered(LibraryStore store) {
    switch (_chip) {
      case 2:
        return sortFiles(store.videos, 1);
      case 3:
        final l = store.videos.where((v) => watchOf(v) == Watch.progress).toList();
        return sortFiles(l, 4);
      default:
        return sortFiles(store.videos, 4);
    }
  }

  List<MediaFolder> _folders(LibraryStore store) {
    final l = store.folders.where((f) => f.videos.isNotEmpty).toList();
    switch (_folderSort) {
      case 1:
        l.sort((a, b) => b.newest.compareTo(a.newest));
        break;
      case 2:
        final recent = Prefs.recentVideo;
        int rank(MediaFolder f) {
          int best = 1 << 30;
          for (final v in f.videos) {
            final i = recent.indexOf(v.path);
            if (i >= 0 && i < best) best = i;
          }
          return best;
        }
        l.sort((a, b) {
          final c = rank(a).compareTo(rank(b));
          return c != 0 ? c : naturalCompare(a.name, b.name);
        });
        break;
      default:
        l.sort((a, b) => naturalCompare(a.name, b.name));
    }
    return l;
  }

  void _toggle(MediaFile f) => setState(() {
        if (!_sel.remove(f.id)) _sel.add(f.id);
      });

  void _openFolder(MediaFolder f) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SeriesScreen(dir: f.path, name: f.name),
    ));
  }

  void _folderMenu(MediaFolder f) {
    final c = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: Text(tr('Open')),
              onTap: () {
                Navigator.pop(sheet);
                _openFolder(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.done_all_rounded),
              title: Text(tr('Mark all as watched')),
              onTap: () {
                Navigator.pop(sheet);
                markWatched(f.videos);
                ShellController.tick.value++;
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_done_rounded),
              title: Text(tr('Mark all as unwatched')),
              onTap: () {
                Navigator.pop(sheet);
                markUnwatched(f.videos);
                ShellController.tick.value++;
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = LibraryStore.instance;
    return SafeArea(
      bottom: false,
      child: PopScope(
        canPop: !_selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(_sel.clear);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('Videos'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
                  ),
                  if (_chip == 0)
                    IconButton(
                      tooltip: 'Grid / list',
                      icon: Icon(Prefs.folderGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                      onPressed: () => setState(() => Prefs.folderGrid = !Prefs.folderGrid),
                    ),
                  if (_chip == 0)
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.sort_rounded),
                      onSelected: (v) {
                        setState(() => _folderSort = v);
                        Prefs.folderSort = v;
                      },
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem<int>(
                            value: 0, checked: _folderSort == 0, child: Text(tr('Name (A–Z)'))),
                        CheckedPopupMenuItem<int>(
                            value: 1, checked: _folderSort == 1, child: Text(tr('Recently added'))),
                        CheckedPopupMenuItem<int>(
                            value: 2, checked: _folderSort == 2, child: Text(tr('Last watched'))),
                      ],
                    ),
                ],
              ),
            ),
            PillChips(
              labels: _labels,
              index: _chip,
              onChanged: (i) {
                setState(() {
                  _chip = i;
                  _sel.clear();
                });
                if (i < 2) Prefs.videoView = i;
              },
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([store, ShellController.tick]),
                builder: (context, _) => StoreGate(
                  builder: (context) => _chip == 0 ? _foldersView(store) : _gridView(store),
                ),
              ),
            ),
            if (_selecting)
              SelectionBar(
                count: _sel.length,
                onClose: () => setState(_sel.clear),
                onSelectAll: () => setState(() => _sel.addAll(_filtered(store).map((v) => v.id))),
                extraActions: [
                  IconButton(
                    tooltip: 'Mark as watched',
                    icon: const Icon(Icons.done_all_rounded),
                    onPressed: () {
                      markWatched(store.videos.where((v) => _sel.contains(v.id)));
                      setState(_sel.clear);
                      ShellController.tick.value++;
                    },
                  ),
                ],
                onDelete: () async {
                  final files = store.videos.where((v) => _sel.contains(v.id)).toList();
                  final ok = await confirmDelete(context, files);
                  if (ok && mounted) setState(_sel.clear);
                },
              ),
          ],
        ),
      ),
    );
  }

  MediaFile? _resumeVideo(LibraryStore store) {
    for (final p in Prefs.recentVideo) {
      final v = store.byPath[p];
      if (v != null && watchOf(v) == Watch.progress) return v;
    }
    return null;
  }

  void _playResume(LibraryStore store, MediaFile v) {
    final matches = store.folders.where((f) => f.path == v.dir).toList();
    final eps = matches.isEmpty ? <MediaFile>[v] : sortFiles(matches.first.videos, 4);
    final i = eps.indexWhere((e) => e.id == v.id);
    playVideos(context, eps, i < 0 ? 0 : i);
  }

  Widget _foldersView(LibraryStore store) {
    final c = AppColors.of(context);
    final folders = _folders(store);
    if (folders.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No video folders',
        hint: 'Folders with videos show up here automatically. Pull down to rescan.',
      );
    }
    final resume = _resumeVideo(store);
    int episodes = 0;
    int watched = 0;
    for (final f in folders) {
      final st = statsOf(f.videos);
      episodes += st.total;
      watched += st.done;
    }
    final grid = Prefs.folderGrid;

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                Text(tr(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(tr(label), style: TextStyle(fontSize: 11.5, color: c.muted)),
              ],
            ),
          ),
        );

    return RefreshIndicator(
      onRefresh: () => store.scan(silent: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (resume != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _ResumeHero(video: resume, onTap: () => _playResume(store, resume)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  stat('${folders.length}', 'Series'),
                  const SizedBox(width: 10),
                  stat('$episodes', 'Episodes'),
                  const SizedBox(width: 10),
                  stat('$watched', 'Watched'),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: SectionHeader(title: 'Your series'),
            ),
          ),
          if (grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _SeriesTile(
                    folder: folders[i],
                    onTap: () => _openFolder(folders[i]),
                    onLongPress: () => _folderMenu(folders[i]),
                  ),
                  childCount: folders.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _FolderCard(
                    folder: folders[i],
                    onTap: () => _openFolder(folders[i]),
                    onLongPress: () => _folderMenu(folders[i]),
                  ),
                  childCount: folders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridView(LibraryStore store) {
    final list = _filtered(store);
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.movie_outlined,
        title: _chip == 3 ? 'Nothing in progress' : 'No videos found',
        hint: _chip == 3
            ? 'Videos you start watching will show up here.'
            : 'MKV, MP4 and more show up here automatically.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => store.scan(silent: true),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 1.15,
        ),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final v = list[i];
          return VideoCard(
            file: v,
            selecting: _selecting,
            selected: _sel.contains(v.id),
            onTap: () => _selecting ? _toggle(v) : playVideos(context, list, i),
            onLongPress: () => _toggle(v),
          );
        },
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final MediaFolder folder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _FolderCard({required this.folder, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final eps = sortFiles(folder.videos, 4);
    final stats = statsOf(eps);
    final target = continueTarget(eps) ?? eps.first;
    final parts = folder.path.split('/');
    final parent = parts.length >= 2 ? parts[parts.length - 2] : '';
    final frac = stats.total == 0 ? 0.0 : stats.done / stats.total;
    final marks = Prefs.showWatched;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(
          children: [
            SizedBox(
              width: 124,
              height: 76,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumb(file: target),
                    Container(color: Colors.black.withOpacity(0.10)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tn('{n} eps', {'n': stats.total}),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(folder.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                    tn(stats.total == 1 ? '{n} episode' : '{n} episodes', {'n': stats.total}) +
                        (marks && stats.done > 0 ? '  ·  ${tn('{n} watched', {'n': stats.done})}' : ''),
                    style: TextStyle(fontSize: 12.5, color: c.muted),
                  ),
                  if (parent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(tn('in {name}', {'name': parent}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: c.muted)),
                    ),
                  if (marks && (stats.done > 0 || stats.inProgress > 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: stats.completed
                          ? Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 15, color: c.accent),
                                const SizedBox(width: 5),
                                Text(tr('Completed'),
                                    style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: frac,
                                minHeight: 4,
                                color: c.accent,
                                backgroundColor: c.border,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _ResumeHero extends StatelessWidget {
  final MediaFile video;
  final VoidCallback onTap;
  const _ResumeHero({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pos = Prefs.position(video.path) ?? 0;
    final total = video.duration.inMilliseconds;
    final left = total > pos ? Duration(milliseconds: total - pos) : Duration.zero;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 8.2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoThumb(file: video),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0xDD000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: Text(tr('CONTINUE WATCHING'),
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
              ),
              const Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.play_arrow_rounded, size: 36, color: Color(0xFF1F1F1F)),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.niceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(tn('{folder}  ·  {time} left', {'folder': video.folder, 'time': fmtDur(left)}),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total > 0 ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0,
                        minHeight: 4,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesTile extends StatelessWidget {
  final MediaFolder folder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _SeriesTile({required this.folder, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final eps = sortFiles(folder.videos, 4);
    final stats = statsOf(eps);
    final target = continueTarget(eps) ?? eps.first;
    final marks = Prefs.showWatched;
    final frac = stats.total == 0 ? 0.0 : stats.done / stats.total;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumb(file: target),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tn('{n} eps', {'n': stats.total}),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (marks && stats.completed)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check_rounded, size: 15, color: Color(0xFF1F1F1F)),
                      ),
                    ),
                  if (marks && !stats.completed && (stats.done > 0 || stats.inProgress > 0))
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 4,
                        color: Colors.white,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.2)),
          const SizedBox(height: 2),
          Text(
            marks && stats.done > 0
                ? tn('{done}/{total} watched', {'done': stats.done, 'total': stats.total})
                : tn(stats.total == 1 ? '{n} episode' : '{n} episodes', {'n': stats.total}),
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
        ],
      ),
    );
  }
}
