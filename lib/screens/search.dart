import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'library.dart';
import 'nav.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _hit(String s) => s.toLowerCase().contains(_q.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search songs, videos, artists…',
            hintStyle: TextStyle(color: c.muted),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v),
          onSubmitted: (v) => setState(() => Prefs.addSearch(v)),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _ctrl.clear();
                _q = '';
              }),
            ),
        ],
      ),
      body: _q.trim().isEmpty ? _recent(c) : _results(c),
    );
  }

  Widget _recent(AppColors c) {
    final recent = Prefs.recentSearches;
    if (recent.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search your library',
        hint: 'Find songs, videos and artists in one place.',
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => Prefs.recentSearches = <String>[]),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        for (final r in recent)
          ListTile(
            leading: Icon(Icons.history_rounded, color: c.muted),
            title: Text(r),
            trailing: IconButton(
              icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
              onPressed: () => setState(() => Prefs.recentSearches = Prefs.recentSearches..remove(r)),
            ),
            onTap: () => setState(() {
              _ctrl.text = r;
              _ctrl.selection = TextSelection.collapsed(offset: r.length);
              _q = r;
            }),
          ),
      ],
    );
  }

  Widget _results(AppColors c) {
    final store = LibraryStore.instance;
    final audio = AudioService.instance;
    final songs = store.songs
        .where((s) => _hit(s.title) || _hit(s.artist) || _hit(s.album))
        .take(30)
        .toList();
    final vids = store.videos.where((v) => _hit(v.title)).take(30).toList();
    final artists = store.artists.keys.where(_hit).take(10).toList();

    if (songs.isEmpty && vids.isEmpty && artists.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        hint: 'Try a different word.',
      );
    }
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (artists.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const SectionHeader(title: 'Artists'),
            ),
          for (final n in artists)
            ListTile(
              leading: ArtImage(path: store.artists[n]!.first.path, size: 44, radius: 22),
              title: Text(n),
              subtitle: Text('${store.artists[n]!.length} songs'),
              onTap: () {
                Prefs.addSearch(_q);
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => TrackListScreen(
                    title: n,
                    source: () => LibraryStore.instance.artists[n] ?? <MediaFile>[],
                  ),
                ));
              },
            ),
          if (songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const SectionHeader(title: 'Songs'),
            ),
          for (int i = 0; i < songs.length; i++)
            SongTile(
              file: songs[i],
              selecting: false,
              selected: false,
              current: audio.current?.id == songs[i].id,
              onTap: () {
                Prefs.addSearch(_q);
                playSongs(context, songs, i);
              },
              onLongPress: () =>
                  showTrackMenu(context, songs[i], onPlay: () => playSongs(context, songs, i)),
              onMenu: () =>
                  showTrackMenu(context, songs[i], onPlay: () => playSongs(context, songs, i)),
            ),
          if (vids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const SectionHeader(title: 'Videos'),
            ),
          for (int i = 0; i < vids.length; i++)
            VideoRow(
              file: vids[i],
              onTap: () {
                Prefs.addSearch(_q);
                playVideos(context, vids, i);
              },
              onMenu: () =>
                  showVideoMenu(context, vids[i], onPlay: () => playVideos(context, vids, i)),
            ),
        ],
      ),
    );
  }
}
