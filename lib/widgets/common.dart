import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/native.dart';
import '../core/playlists.dart';
import '../core/prefs.dart';
import '../core/theme.dart';

// ───────────────────────── formatting ─────────────────────────
String fmtDur(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double s = bytes.toDouble();
  int i = 0;
  while (s >= 1024 && i < units.length - 1) {
    s /= 1024;
    i++;
  }
  return '${s.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String resLabel(int h) {
  if (h <= 0) return '';
  if (h >= 2160) return '4K';
  return '${h}p';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

// ───────────────────────── artwork ─────────────────────────
class ArtCache {
  static final Map<String, Uint8List?> _m = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _pending = <String, Future<Uint8List?>>{};

  static bool has(String path) => _m.containsKey(path);
  static Uint8List? peek(String path) => _m[path];

  static Future<Uint8List?> get(String path) {
    if (_m.containsKey(path)) return Future<Uint8List?>.value(_m[path]);
    return _pending[path] ??= Native.audioArt(path).then((b) {
      if (_m.length > 400) _m.clear();
      _m[path] = b;
      _pending.remove(path);
      return b;
    });
  }
}

class ArtImage extends StatelessWidget {
  final String path;
  final double? size;
  final double radius;
  const ArtImage({super.key, required this.path, this.size, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final placeholder = Image.asset('assets/album_placeholder.png', fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: ArtCache.get(path),
          initialData: ArtCache.peek(path),
          builder: (context, snap) {
            final d = snap.data;
            if (d != null) return Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true);
            return placeholder;
          },
        ),
      ),
    );
  }
}

final Map<String, Uint8List> _thumbCache = <String, Uint8List>{};

class VideoThumb extends StatefulWidget {
  final MediaFile file;
  const VideoThumb({super.key, required this.file});

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  late final Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() async {
    final id = widget.file.id;
    final cached = _thumbCache[id];
    if (cached != null) return cached;
    try {
      final asset = await AssetEntity.fromId(id);
      final data = await asset?.thumbnailDataWithSize(const ThumbnailSize(360, 220), quality: 80);
      if (data != null) {
        if (_thumbCache.length > 300) _thumbCache.clear();
        _thumbCache[id] = data;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<Uint8List?>(
      future: _future,
      initialData: _thumbCache[widget.file.id],
      builder: (context, snap) {
        final d = snap.data;
        if (d != null) return Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true);
        return Container(
          color: c.surface2,
          child: Center(child: Icon(Icons.movie_outlined, color: c.muted, size: 28)),
        );
      },
    );
  }
}

// ───────────────────────── small building blocks ─────────────────────────
class PillChips extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillChips({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sel = i == index;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? c.accent : c.surface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: sel ? c.onAccent : c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SearchBarTile extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;
  const SearchBarTile({super.key, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: c.muted, size: 22),
            const SizedBox(width: 10),
            Text(hint, style: TextStyle(color: c.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: TextStyle(fontSize: 13, color: c.muted)),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  const EmptyState({super.key, required this.icon, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: c.border),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(color: c.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  const _CheckDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.accent : Colors.transparent,
        border: Border.all(color: selected ? c.accent : c.muted, width: 1.6),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 16, color: c.onAccent) : null,
    );
  }
}

// ───────────────────────── list items ─────────────────────────
class SongTile extends StatelessWidget {
  final MediaFile file;
  final bool selecting;
  final bool selected;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  const SongTile({
    super.key,
    required this.file,
    required this.selecting,
    required this.selected,
    required this.current,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? c.surface2 : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(20, 7, 8, 7),
        child: Row(
          children: [
            ArtImage(path: file.path, size: 50, radius: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.niceTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (current)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.graphic_eq_rounded, size: 20, color: c.accent),
              )
            else
              Text(fmtDur(file.duration), style: TextStyle(fontSize: 12.5, color: c.muted)),
            if (selecting)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                child: _CheckDot(selected: selected),
              )
            else
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: c.muted, size: 20),
                onPressed: onMenu,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final MediaFile file;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const VideoCard({
    super.key,
    required this.file,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pos = Prefs.position(file.path);
    final total = file.duration.inMilliseconds;
    final progress =
        (pos != null && total > 0) ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumb(file: file),
                  Container(color: Colors.black.withOpacity(selected ? 0.38 : 0.12)),
                  const Center(
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                  ),
                  if (file.duration > Duration.zero)
                    Positioned(
                      right: 6,
                      bottom: progress > 0 ? 9 : 6,
                      child: _Badge(fmtDur(file.duration)),
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
                  if (selecting)
                    Positioned(top: 8, right: 8, child: _CheckDot(selected: selected)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            file.niceTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            [if (resLabel(file.height).isNotEmpty) resLabel(file.height), file.ext].join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class VideoRow extends StatelessWidget {
  final MediaFile file;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  const VideoRow({super.key, required this.file, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pos = Prefs.position(file.path);
    final total = file.duration.inMilliseconds;
    final progress =
        (pos != null && total > 0) ? (pos / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 7, 4, 7),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumb(file: file),
                    if (file.duration > Duration.zero)
                      Positioned(
                        right: 4,
                        bottom: progress > 0 ? 7 : 4,
                        child: _Badge(fmtDur(file.duration)),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.niceTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                    [if (resLabel(file.height).isNotEmpty) resLabel(file.height), file.ext].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: c.muted, size: 20),
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── selection bar ─────────────────────────
class SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;

  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.onDelete,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
              Text('$count selected', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Select all',
                icon: const Icon(Icons.select_all_rounded),
                onPressed: onSelectAll,
              ),
              if (onAddToPlaylist != null)
                IconButton(
                  tooltip: 'Add to playlist',
                  icon: const Icon(Icons.playlist_add_rounded),
                  onPressed: onAddToPlaylist,
                ),
              if (onRemoveFromPlaylist != null)
                IconButton(
                  tooltip: 'Remove from playlist',
                  icon: const Icon(Icons.playlist_remove_rounded),
                  onPressed: onRemoveFromPlaylist,
                ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── sheets and dialogs ─────────────────────────
Widget _menuTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: onTap,
    dense: true,
  );
}

void _sheet(BuildContext context, String title, List<Widget> items) {
  final c = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          Flexible(child: ListView(shrinkWrap: true, children: items)),
        ],
      ),
    ),
  );
}

void showTrackMenu(BuildContext context, MediaFile f,
    {required VoidCallback onPlay, String? playlist}) {
  final audio = AudioService.instance;
  final store = PlaylistStore.instance;
  final fav = store.isFav(f.path);
  _sheet(context, f.niceTitle, [
    _menuTile(Icons.play_arrow_rounded, 'Play', () {
      Navigator.pop(context);
      onPlay();
    }),
    _menuTile(Icons.queue_play_next_rounded, 'Play next', () {
      Navigator.pop(context);
      audio.playNext(f);
      toast(context, 'Will play next');
    }),
    _menuTile(Icons.playlist_play_rounded, 'Add to queue', () {
      Navigator.pop(context);
      audio.addToQueue(f);
      toast(context, 'Added to queue');
    }),
    _menuTile(Icons.playlist_add_rounded, 'Add to playlist', () {
      Navigator.pop(context);
      showAddToPlaylist(context, [f.path]);
    }),
    _menuTile(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        fav ? 'Remove from favorites' : 'Add to favorites', () {
      Navigator.pop(context);
      store.toggleFav(f.path);
    }),
    if (playlist != null)
      _menuTile(Icons.playlist_remove_rounded, 'Remove from this playlist', () {
        Navigator.pop(context);
        if (playlist == kFavoritesName) {
          store.toggleFav(f.path);
        } else {
          store.removeFrom(playlist, [f.path]);
        }
      }),
    _menuTile(Icons.info_outline_rounded, 'Properties', () {
      Navigator.pop(context);
      showInfo(context, f);
    }),
    _menuTile(Icons.delete_outline_rounded, 'Delete', () {
      Navigator.pop(context);
      confirmDelete(context, [f]);
    }, color: Colors.redAccent),
  ]);
}

void showVideoMenu(BuildContext context, MediaFile f, {required VoidCallback onPlay}) {
  _sheet(context, f.niceTitle, [
    _menuTile(Icons.play_arrow_rounded, 'Play', () {
      Navigator.pop(context);
      onPlay();
    }),
    _menuTile(Icons.info_outline_rounded, 'Properties', () {
      Navigator.pop(context);
      showInfo(context, f);
    }),
    _menuTile(Icons.delete_outline_rounded, 'Delete', () {
      Navigator.pop(context);
      confirmDelete(context, [f]);
    }, color: Colors.redAccent),
  ]);
}

const String kFavoritesName = 'My Favorites';

void showAddToPlaylist(BuildContext context, List<String> paths) {
  final store = PlaylistStore.instance;
  _sheet(context, 'Add to playlist', [
    _menuTile(Icons.add_rounded, 'New playlist', () async {
      Navigator.pop(context);
      final name = await askText(context, title: 'New playlist', hint: 'Playlist name');
      if (name == null) return;
      if (store.create(name)) {
        store.addAll(name.trim(), paths);
        if (context.mounted) toast(context, 'Added to ${name.trim()}');
      } else if (context.mounted) {
        toast(context, 'A playlist with that name already exists');
      }
    }),
    _menuTile(Icons.favorite_border_rounded, kFavoritesName, () {
      Navigator.pop(context);
      for (final p in paths) {
        if (!store.isFav(p)) store.toggleFav(p);
      }
      toast(context, 'Added to favorites');
    }),
    for (final name in store.lists.keys)
      _menuTile(Icons.queue_music_rounded, name, () {
        Navigator.pop(context);
        store.addAll(name, paths);
        toast(context, 'Added to $name');
      }),
  ]);
}

Future<String?> askText(BuildContext context,
    {required String title, String hint = '', String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(dialog, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialog, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

void showInfo(BuildContext context, MediaFile f) {
  final c = AppColors.of(context);
  int? size;
  try {
    size = File(f.path).lengthSync();
  } catch (_) {}
  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(fontSize: 11, color: c.muted, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            SelectableText(v, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
  final d = f.added;
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Properties'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('NAME', f.title),
            row('LOCATION', f.path),
            if (size != null) row('SIZE', fmtSize(size)),
            row('DURATION', fmtDur(f.duration)),
            if (!f.isVideo) row('ARTIST', f.artist),
            if (!f.isVideo) row('ALBUM', f.album),
            if (f.isVideo && f.height > 0) row('RESOLUTION', '${f.width} × ${f.height}'),
            row('DATE ADDED',
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close')),
      ],
    ),
  );
}

/// Returns true when files were deleted.
Future<bool> confirmDelete(BuildContext context, List<MediaFile> files) async {
  if (files.isEmpty) return false;
  final messenger = ScaffoldMessenger.of(context);
  final what = files.length == 1 ? '"${files.first.niceTitle}"' : '${files.length} files';
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(files.length == 1 ? 'Delete file?' : 'Delete ${files.length} files?'),
      content: Text('$what will be permanently deleted from your phone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final audio = AudioService.instance;
  final ids = files.map((f) => f.id).toSet();
  if (audio.current != null && ids.contains(audio.current!.id)) await audio.stop();
  int n = 0;
  try {
    n = await LibraryStore.instance.delete(files);
  } catch (_) {}
  messenger.showSnackBar(SnackBar(
    content: Text(n == files.length
        ? (n == 1 ? 'File deleted' : '$n files deleted')
        : (n > 0 ? '$n of ${files.length} files deleted' : 'Could not delete')),
  ));
  return n > 0;
}

// ───────────────────────── mini player ─────────────────────────
class MiniPlayerBar extends StatelessWidget {
  final VoidCallback onTap;
  const MiniPlayerBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = AudioService.instance;
    return ListenableBuilder(
      listenable: a,
      builder: (context, _) {
        final t = a.current;
        if (t == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.25),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(
                  children: [
                    ArtImage(path: t.path, size: 44, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.niceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(t.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: IconButton(
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          a.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: c.onAccent,
                        ),
                        onPressed: () => a.player.playOrPause(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
                      onPressed: () => a.stop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── waveform seek bar ─────────────────────────
/// Decorative waveform (generated from the file name) used as a seek bar.
class WaveformSeek extends StatefulWidget {
  final String seed;
  final double progress; // 0..1
  final ValueChanged<double> onSeek;
  const WaveformSeek({super.key, required this.seed, required this.progress, required this.onSeek});

  @override
  State<WaveformSeek> createState() => _WaveformSeekState();
}

class _WaveformSeekState extends State<WaveformSeek> {
  double? _drag;

  double _frac(double dx, double w) => (dx / w).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onSeek(_frac(d.localPosition.dx, w)),
          onHorizontalDragStart: (d) => setState(() => _drag = _frac(d.localPosition.dx, w)),
          onHorizontalDragUpdate: (d) => setState(() => _drag = _frac(d.localPosition.dx, w)),
          onHorizontalDragEnd: (_) {
            final v = _drag;
            setState(() => _drag = null);
            if (v != null) widget.onSeek(v);
          },
          child: CustomPaint(
            size: Size(w, 56),
            painter: _WavePainter(
              seed: widget.seed,
              progress: _drag ?? widget.progress,
              active: c.accent,
              inactive: c.muted.withOpacity(0.45),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final String seed;
  final double progress;
  final Color active;
  final Color inactive;
  _WavePainter({required this.seed, required this.progress, required this.active, required this.inactive});

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 3.0;
    final count = (size.width / (barW + gap)).floor();
    int h = 7;
    for (final u in seed.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    final rnd = math.Random(h);
    final phase = rnd.nextDouble() * 6.28;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    final mid = size.height / 2;
    for (int i = 0; i < count; i++) {
      final env = 0.45 + 0.55 * math.sin(i * 0.11 + phase).abs();
      final v = 0.18 + 0.82 * (0.55 * rnd.nextDouble() + 0.45 * env);
      final half = (size.height * 0.5) * v;
      final x = i * (barW + gap) + barW / 2;
      paint.color = (i / count) <= progress ? active : inactive;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.seed != seed || old.active != active;
}
