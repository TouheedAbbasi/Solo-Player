import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/watch.dart';
import '../widgets/common.dart';
import 'nav.dart';
import '../core/strings.dart';

/// One folder = one series. Episodes are shown in natural order
/// (Episode 2 before Episode 10) with watched marks and a Continue button.
class SeriesScreen extends StatefulWidget {
  final String dir;
  final String name;
  const SeriesScreen({super.key, required this.dir, required this.name});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  final LibraryStore _store = LibraryStore.instance;
  int _sort = Prefs.episodeSort;
  final Set<String> _sel = <String>{};
  bool get _selecting => _sel.isNotEmpty;

  int get _mode => _sort == 0 ? 4 : (_sort == 1 ? 5 : 1);

  List<MediaFile> _videos() {
    final m = _store.folders.where((f) => f.path == widget.dir).toList();
    return m.isEmpty ? <MediaFile>[] : m.first.videos;
  }

  void _toggle(MediaFile f) => setState(() {
        if (!_sel.remove(f.id)) _sel.add(f.id);
      });

  void _refresh() {
    ShellController.tick.value++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) {
              setState(() => _sort = v);
              Prefs.episodeSort = v;
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<int>(value: 0, checked: _sort == 0, child: Text(tr('Episode order (A–Z)'))),
              CheckedPopupMenuItem<int>(value: 1, checked: _sort == 1, child: Text(tr('Reverse order (Z–A)'))),
              CheckedPopupMenuItem<int>(value: 2, checked: _sort == 2, child: Text(tr('Newest first'))),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              final all = _videos();
              if (v == 'watched') markWatched(all);
              if (v == 'unwatched') markUnwatched(all);
              _refresh();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(value: 'watched', child: Text(tr('Mark all as watched'))),
              PopupMenuItem<String>(value: 'unwatched', child: Text(tr('Mark all as unwatched'))),
            ],
          ),
        ],
      ),
      body: PopScope(
        canPop: !_selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(_sel.clear);
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([_store, ShellController.tick]),
          builder: (context, _) {
            final inOrder = sortFiles(_videos(), 4);
            if (inOrder.isEmpty) {
              return const EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'No videos here',
                hint: 'This folder has no videos any more.',
              );
            }
            final display = sortFiles(inOrder, _mode);
            final stats = statsOf(inOrder);
            final target = continueTarget(inOrder) ?? inOrder.first;

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: display.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _header(inOrder, stats, target);
                      final e = display[index - 1];
                      final playIndex = inOrder.indexWhere((x) => x.id == e.id);
                      void play() => playVideos(context, inOrder, playIndex < 0 ? 0 : playIndex);
                      return VideoRow(
                        file: e,
                        selecting: _selecting,
                        selected: _sel.contains(e.id),
                        onTap: () => _selecting ? _toggle(e) : play(),
                        onLongPress: () => _toggle(e),
                        onMenu: () => showVideoMenu(context, e, onPlay: play),
                      );
                    },
                  ),
                ),
                if (_selecting)
                  SelectionBar(
                    count: _sel.length,
                    onClose: () => setState(_sel.clear),
                    onSelectAll: () => setState(() => _sel.addAll(inOrder.map((v) => v.id))),
                    extraActions: [
                      IconButton(
                        tooltip: 'Mark as watched',
                        icon: const Icon(Icons.done_all_rounded),
                        onPressed: () {
                          markWatched(inOrder.where((v) => _sel.contains(v.id)));
                          _sel.clear();
                          _refresh();
                        },
                      ),
                      IconButton(
                        tooltip: 'Mark as unwatched',
                        icon: const Icon(Icons.remove_done_rounded),
                        onPressed: () {
                          markUnwatched(inOrder.where((v) => _sel.contains(v.id)));
                          _sel.clear();
                          _refresh();
                        },
                      ),
                    ],
                    onDelete: () async {
                      final files = inOrder.where((v) => _sel.contains(v.id)).toList();
                      final ok = await confirmDelete(context, files);
                      if (ok && mounted) setState(_sel.clear);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(List<MediaFile> inOrder, WatchStats stats, MediaFile target) {
    final c = AppColors.of(context);
    final marks = Prefs.showWatched;
    final label = stats.completed
        ? 'Watch again'
        : ((stats.done == 0 && stats.inProgress == 0) ? 'Start watching' : 'Continue watching');
    final idx = inOrder.indexWhere((x) => x.id == target.id);
    void play() => playVideos(context, inOrder, idx < 0 ? 0 : idx);
    final frac = stats.total == 0 ? 0.0 : stats.done / stats.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: play,
            child: AspectRatio(
              aspectRatio: 16 / 8.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumb(file: target),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.play_arrow_rounded, size: 34, color: Color(0xFF1F1F1F)),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            tn(stats.total == 1 ? '{n} episode' : '{n} episodes', {'n': stats.total}) +
                                (marks ? '  ·  ${tn('{n} watched', {'n': stats.done})}' : ''),
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (marks && stats.total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 4,
                color: c.accent,
                backgroundColor: c.border,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.onAccent,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: play,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(tr(label)),
            ),
          ),
          const SizedBox(height: 8),
          Text(target.niceTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
      ),
    );
  }
}
