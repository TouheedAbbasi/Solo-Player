import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/playlists.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/gate.dart';
import 'nav.dart';
import 'search.dart';

// ───────────────────────── reusable track list with multi-select ─────────────────────────
class TrackList extends StatefulWidget {
  final List<MediaFile> tracks;
  final String? playlist;
  final bool header;
  const TrackList({super.key, required this.tracks, this.playlist, this.header = true});

  @override
  State<TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<TrackList> {
  final Set<String> _sel = <String>{};
  bool get _selecting => _sel.isNotEmpty;

  void _toggle(MediaFile f) => setState(() {
        if (!_sel.remove(f.id)) _sel.add(f.id);
      });

  List<MediaFile> get _selected => widget.tracks.where((t) => _sel.contains(t.id)).toList();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tracks = widget.tracks;
    final audio = AudioService.instance;
    final showHeader = widget.header && tracks.isNotEmpty;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_sel.clear);
      },
      child: Column(
        children: [
          Expanded(
            child: tracks.isEmpty
                ? const EmptyState(
                    icon: Icons.music_off_rounded,
                    title: 'No songs here',
                    hint: 'Songs will appear here automatically.',
                  )
                : ListenableBuilder(
                    listenable: audio,
                    builder: (context, _) => ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: tracks.length + (showHeader ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showHeader && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: c.accent,
                                      foregroundColor: c.onAccent,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () => playSongs(context, tracks, 0),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text('Play all (${tracks.length})'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.text,
                                      side: BorderSide(color: c.border),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () => playSongs(context, tracks, 0, shuffle: true),
                                    icon: const Icon(Icons.shuffle_rounded),
                                    label: const Text('Shuffle'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final i = showHeader ? index - 1 : index;
                        final t = tracks[i];
                        return SongTile(
                          file: t,
                          selecting: _selecting,
                          selected: _sel.contains(t.id),
                          current: audio.current?.id == t.id,
                          onTap: () => _selecting ? _toggle(t) : playSongs(context, tracks, i),
                          onLongPress: () => _toggle(t),
                          onMenu: () => showTrackMenu(
                            context,
                            t,
                            playlist: widget.playlist,
                            onPlay: () => playSongs(context, tracks, i),
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
              onSelectAll: () => setState(() => _sel.addAll(tracks.map((t) => t.id))),
              onAddToPlaylist: () {
                showAddToPlaylist(context, _selected.map((e) => e.path).toList());
                setState(_sel.clear);
              },
              onRemoveFromPlaylist: widget.playlist == null
                  ? null
                  : () {
                      final paths = _selected.map((e) => e.path).toList();
                      final pl = PlaylistStore.instance;
                      if (widget.playlist == kFavoritesName) {
                        for (final p in paths) {
                          if (pl.isFav(p)) pl.toggleFav(p);
                        }
                      } else {
                        pl.removeFrom(widget.playlist!, paths);
                      }
                      setState(_sel.clear);
                    },
              onDelete: () async {
                final ok = await confirmDelete(context, _selected);
                if (ok && mounted) setState(_sel.clear);
              },
            ),
        ],
      ),
    );
  }
}

class TrackListScreen extends StatelessWidget {
  final String title;
  final List<MediaFile> Function() source;
  final String? playlist;
  const TrackListScreen({super.key, required this.title, required this.source, this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListenableBuilder(
        listenable: Listenable.merge([LibraryStore.instance, PlaylistStore.instance]),
        builder: (context, _) => TrackList(tracks: source(), playlist: playlist),
      ),
    );
  }
}

class FolderScreen extends StatelessWidget {
  final String dir;
  final String name;
  const FolderScreen({super.key, required this.dir, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = LibraryStore.instance;
    final audio = AudioService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, audio]),
        builder: (context, _) {
          final matches = store.folders.where((f) => f.path == dir).toList();
          if (matches.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'Folder is empty',
              hint: 'There are no media files here.',
            );
          }
          final folder = matches.first;
          final vids = sortFiles(folder.videos, 0);
          final songs = sortFiles(folder.audios, 0);
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (vids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text('VIDEOS  ·  ${vids.length}',
                      style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: c.muted, fontWeight: FontWeight.w700)),
                ),
              for (int i = 0; i < vids.length; i++)
                VideoRow(
                  file: vids[i],
                  onTap: () => playVideos(context, vids, i),
                  onMenu: () => showVideoMenu(context, vids[i], onPlay: () => playVideos(context, vids, i)),
                ),
              if (songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text('MUSIC  ·  ${songs.length}',
                      style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: c.muted, fontWeight: FontWeight.w700)),
                ),
              for (int i = 0; i < songs.length; i++)
                SongTile(
                  file: songs[i],
                  selecting: false,
                  selected: false,
                  current: audio.current?.id == songs[i].id,
                  onTap: () => playSongs(context, songs, i),
                  onLongPress: () => showTrackMenu(context, songs[i],
                      onPlay: () => playSongs(context, songs, i)),
                  onMenu: () => showTrackMenu(context, songs[i],
                      onPlay: () => playSongs(context, songs, i)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Library tab ─────────────────────────
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  static const List<String> _labels = ['Songs', 'Artists', 'Albums', 'Playlists', 'Folders'];
  int _sort = Prefs.sort > 3 ? 1 : Prefs.sort;
  int _artistOrder = 0;

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final store = LibraryStore.instance;
    final pl = PlaylistStore.instance;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Library', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _push(const SearchScreen()),
                ),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: (v) {
                    setState(() => _sort = v);
                    Prefs.sort = v;
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem<int>(value: 0, checked: _sort == 0, child: const Text('Name (A–Z)')),
                    CheckedPopupMenuItem<int>(value: 1, checked: _sort == 1, child: const Text('Newest first')),
                    CheckedPopupMenuItem<int>(value: 2, checked: _sort == 2, child: const Text('Longest first')),
                    CheckedPopupMenuItem<int>(value: 3, checked: _sort == 3, child: const Text('Artist')),
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: ShellController.libraryChip,
            builder: (context, chip, _) => PillChips(
              labels: _labels,
              index: chip,
              onChanged: (i) => ShellController.libraryChip.value = i,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([store, pl, ShellController.libraryChip]),
              builder: (context, _) => StoreGate(
                builder: (context) {
                  switch (ShellController.libraryChip.value) {
                    case 1:
                      return _artists(store);
                    case 2:
                      return _albums(store);
                    case 3:
                      return _playlists(store, pl);
                    case 4:
                      return _folders(store);
                    default:
                      return TrackList(tracks: sortFiles(store.songs, _sort));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── artists ─────────
  Widget _artists(LibraryStore store) {
    final c = AppColors.of(context);
    final names = store.artists.keys.toList();
    if (_artistOrder == 1) {
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      names.sort((a, b) => store.artists[b]!.length.compareTo(store.artists[a]!.length));
    }
    if (names.isEmpty) {
      return const EmptyState(icon: Icons.person_outline_rounded, title: 'No artists', hint: 'Artists come from your songs.');
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: PillChips(
            labels: const ['Most songs', 'A–Z'],
            index: _artistOrder,
            onChanged: (i) => setState(() => _artistOrder = i),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, i) {
              final n = names[i];
              final tracks = store.artists[n]!;
              return InkWell(
                onTap: () => _push(TrackListScreen(
                  title: n,
                  source: () => LibraryStore.instance.artists[n] ?? <MediaFile>[],
                )),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      ArtImage(path: tracks.first.path, size: 52, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
                                style: TextStyle(fontSize: 12.5, color: c.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.muted),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────── albums ─────────
  Widget _albums(LibraryStore store) {
    final c = AppColors.of(context);
    final albums = store.albums;
    if (albums.isEmpty) {
      return const EmptyState(icon: Icons.album_outlined, title: 'No albums', hint: 'Albums come from your songs.');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return GestureDetector(
          onTap: () => _push(TrackListScreen(
            title: a.title,
            source: () => LibraryStore.instance.albums
                .firstWhere((x) => x.title == a.title && x.artist == a.artist, orElse: () => Album(a.title, a.artist))
                .tracks,
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 1, child: ArtImage(path: a.tracks.first.path, radius: 16)),
              const SizedBox(height: 8),
              Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(a.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ),
        );
      },
    );
  }

  // ───────── playlists ─────────
  List<MediaFile> _resolve(LibraryStore store, List<String> paths) =>
      paths.map((p) => store.byPath[p]).whereType<MediaFile>().toList();

  Widget _playlists(LibraryStore store, PlaylistStore pl) {
    final c = AppColors.of(context);
    Widget tile(String name, List<MediaFile> tracks, {required bool isFav}) {
      return InkWell(
        onTap: () => _push(TrackListScreen(
          title: name,
          playlist: name,
          source: () => isFav
              ? _resolve(LibraryStore.instance, PlaylistStore.instance.favorites)
              : _resolve(LibraryStore.instance, PlaylistStore.instance.lists[name] ?? <String>[]),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              isFav || tracks.isEmpty
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                      child: Icon(isFav ? Icons.favorite_rounded : Icons.queue_music_rounded, color: c.accent),
                    )
                  : ArtImage(path: tracks.first.path, size: 52, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
                        style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
              if (!isFav)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.muted),
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final n = await askText(context, title: 'Rename playlist', initial: name);
                      if (n != null && !pl.lists.containsKey(n.trim())) pl.rename(name, n);
                    } else {
                      pl.delete(name);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Delete playlist')),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: GestureDetector(
            onTap: () async {
              final n = await askText(context, title: 'New playlist', hint: 'Playlist name');
              if (n == null) return;
              if (!pl.create(n) && mounted) toast(context, 'Enter a new, unique name');
            },
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 6),
                  Text('Create Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
        tile(kFavoritesName, _resolve(store, pl.favorites), isFav: true),
        for (final name in pl.lists.keys)
          tile(name, _resolve(store, pl.lists[name] ?? <String>[]), isFav: false),
      ],
    );
  }

  // ───────── folders ─────────
  Widget _folders(LibraryStore store) {
    final c = AppColors.of(context);
    final folders = store.folders;
    if (folders.isEmpty) {
      return const EmptyState(icon: Icons.folder_open_rounded, title: 'No folders', hint: 'Folders with media show up here.');
    }
    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final f = folders[i];
        return InkWell(
          onTap: () => _push(FolderScreen(dir: f.path, name: f.name)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.folder_rounded, color: c.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${f.count} files'
                        '${f.videos.isNotEmpty && f.audios.isNotEmpty ? '  ·  ${f.videos.length} videos, ${f.audios.length} songs' : ''}',
                        style: TextStyle(fontSize: 12.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}
