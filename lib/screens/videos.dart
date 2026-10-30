import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/prefs.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';
import 'nav.dart';
import 'search.dart';

class VideosTab extends StatefulWidget {
  const VideosTab({super.key});

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  static const List<String> _labels = ['All', 'Recently Added', 'In Progress'];
  int _chip = 0;
  final Set<String> _sel = <String>{};
  bool get _selecting => _sel.isNotEmpty;

  List<MediaFile> _filtered(LibraryStore store) {
    switch (_chip) {
      case 1:
        return sortFiles(store.videos, 1);
      case 2:
        final l = store.videos.where((v) {
          final pos = Prefs.position(v.path) ?? 0;
          return pos > 3000 && (v.duration == Duration.zero || pos < v.duration.inMilliseconds - 5000);
        }).toList();
        return sortFiles(l, 0);
      default:
        return sortFiles(store.videos, 0);
    }
  }

  void _toggle(MediaFile f) => setState(() {
        if (!_sel.remove(f.id)) _sel.add(f.id);
      });

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
                  const Expanded(
                    child: Text('Videos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
                  ),
                ],
              ),
            ),
            PillChips(
              labels: _labels,
              index: _chip,
              onChanged: (i) => setState(() => _chip = i),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([store, ShellController.tick]),
                builder: (context, _) => StoreGate(
                  builder: (context) {
                    final list = _filtered(store);
                    if (list.isEmpty) {
                      return EmptyState(
                        icon: Icons.movie_outlined,
                        title: _chip == 2 ? 'Nothing in progress' : 'No videos found',
                        hint: _chip == 2
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
                  },
                ),
              ),
            ),
            if (_selecting)
              SelectionBar(
                count: _sel.length,
                onClose: () => setState(_sel.clear),
                onSelectAll: () => setState(() => _sel.addAll(_filtered(store).map((v) => v.id))),
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
}
