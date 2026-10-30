import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'native.dart';
import 'playlists.dart';
import 'prefs.dart';

int _n(Object? v) => (v as num?)?.toInt() ?? 0;

String _clean(Object? v, String fallback) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty || s == '<unknown>' || s.toLowerCase() == 'unknown') return fallback;
  return s;
}

class MediaFile {
  final String id;
  final String path;
  final String title;
  final String folder;
  final String dir;
  final String artist;
  final String album;
  final bool isVideo;
  final Duration duration;
  final int width;
  final int height;
  final DateTime added;
  final int size;

  const MediaFile({
    required this.id,
    required this.path,
    required this.title,
    required this.folder,
    required this.dir,
    required this.artist,
    required this.album,
    required this.isVideo,
    required this.duration,
    required this.width,
    required this.height,
    required this.added,
    required this.size,
  });

  factory MediaFile.fromMap(Map<String, dynamic> m, bool isVideo) {
    final path = (m['path'] ?? '').toString();
    final rawTitle = (m['title'] ?? '').toString();
    return MediaFile(
      id: '${m['id']}',
      path: path,
      title: rawTitle.isNotEmpty ? rawTitle : path.split('/').last,
      folder: (m['folder'] ?? 'Storage').toString(),
      dir: (m['dir'] ?? '').toString(),
      artist: _clean(m['artist'], 'Unknown artist'),
      album: _clean(m['album'], 'Unknown album'),
      isVideo: isVideo,
      duration: Duration(milliseconds: _n(m['duration'])),
      width: _n(m['width']),
      height: _n(m['height']),
      added: DateTime.fromMillisecondsSinceEpoch(_n(m['added']) * 1000),
      size: _n(m['size']),
    );
  }

  String get ext {
    final i = title.lastIndexOf('.');
    return i < 0 ? '' : title.substring(i + 1).toUpperCase();
  }

  /// Title without the extension, for display in music lists.
  String get niceTitle {
    final i = title.lastIndexOf('.');
    return i > 0 ? title.substring(0, i) : title;
  }
}

class Album {
  final String title;
  final String artist;
  final List<MediaFile> tracks = <MediaFile>[];
  Album(this.title, this.artist);
}

class MediaFolder {
  final String path;
  final String name;
  final List<MediaFile> videos = <MediaFile>[];
  final List<MediaFile> audios = <MediaFile>[];
  MediaFolder(this.path, this.name);
  int get count => videos.length + audios.length;
}

/// mode: 0 name, 1 newest, 2 longest, 3 artist
List<MediaFile> sortFiles(List<MediaFile> src, int mode) {
  final l = List<MediaFile>.of(src);
  switch (mode) {
    case 0:
      l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
    case 2:
      l.sort((a, b) => b.duration.compareTo(a.duration));
      break;
    case 3:
      l.sort((a, b) {
        final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      break;
    default:
      l.sort((a, b) => b.added.compareTo(a.added));
  }
  return l;
}

enum ScanState { idle, loading, denied, ready }

class LibraryStore extends ChangeNotifier {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  static const Set<String> _videoExt = {
    'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv', 'wmv', 'm4v', 'ts', 'mpg', 'mpeg', 'ogv',
  };
  static const Set<String> _audioExt = {
    'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'wma', 'amr',
  };

  List<MediaFile> videos = [];
  List<MediaFile> allAudio = [];
  ScanState state = ScanState.idle;
  String report = '';
  bool _deepRunning = false;

  // derived data (rebuilt by _reindex)
  List<MediaFile> songs = [];
  Map<String, List<MediaFile>> artists = {};
  List<Album> albums = [];
  List<MediaFolder> folders = [];
  Map<String, MediaFile> byPath = {};

  void _reindex() {
    final minSec = Prefs.minAudioSec;
    songs = allAudio.where((a) => a.duration.inSeconds >= minSec || a.duration == Duration.zero).toList();

    final art = <String, List<MediaFile>>{};
    final alb = <String, Album>{};
    for (final s in songs) {
      (art[s.artist] ??= []).add(s);
      final key = '${s.album}|${s.artist}';
      (alb[key] ??= Album(s.album, s.artist)).tracks.add(s);
    }
    artists = art;
    albums = alb.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final fm = <String, MediaFolder>{};
    for (final v in videos) {
      (fm[v.dir] ??= MediaFolder(v.dir, v.folder)).videos.add(v);
    }
    for (final a in songs) {
      (fm[a.dir] ??= MediaFolder(a.dir, a.folder)).audios.add(a);
    }
    folders = fm.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    byPath = {for (final f in [...videos, ...allAudio]) f.path: f};
  }

  /// Call after changing "hide short audio".
  void refreshIndex() {
    _reindex();
    notifyListeners();
  }

  Future<void> scan({bool silent = false}) async {
    if (!silent) {
      state = ScanState.loading;
      notifyListeners();
    }
    final log = StringBuffer();
    final granted = await Native.requestPermission();
    log.writeln('Permission: ${granted ? 'granted' : 'DENIED'}');
    if (!granted) {
      state = ScanState.denied;
      report = log.toString();
      notifyListeners();
      return;
    }
    await _query(log);
    state = ScanState.ready;
    report = log.toString();
    notifyListeners();
    _deepScan(log);
  }

  Future<void> _query(StringBuffer log) async {
    try {
      final raw = await Native.scanRaw(true);
      videos = raw.map((m) => MediaFile.fromMap(m, true)).toList();
    } catch (e) {
      log.writeln('Video query error: $e');
    }
    try {
      final raw = await Native.scanRaw(false);
      allAudio = raw.map((m) => MediaFile.fromMap(m, false)).toList();
    } catch (e) {
      log.writeln('Audio query error: $e');
    }
    _reindex();
    log.writeln('Library: ${videos.length} videos, ${allAudio.length} audio files');
  }

  /// Finds media files Android has not indexed yet (e.g. copied over USB)
  /// and asks Android to index them.
  Future<void> _deepScan(StringBuffer log) async {
    if (_deepRunning) return;
    _deepRunning = true;
    try {
      final known = <String>{
        ...videos.map((e) => e.path),
        ...allAudio.map((e) => e.path),
      };
      final found = await _walkAll(known);
      log.writeln('Files on storage missing from library: ${found.length}');
      if (found.isNotEmpty) {
        await Native.indexFiles(found.take(3000).toList());
        await _query(log);
        notifyListeners();
      }
    } catch (e) {
      log.writeln('Deep scan error: $e');
    } finally {
      _deepRunning = false;
      report = log.toString();
    }
  }

  Future<List<String>> _walkAll(Set<String> known) async {
    final roots = <Directory>[Directory('/storage/emulated/0')];
    try {
      await for (final e in Directory('/storage').list(followLinks: false)) {
        final name = e.path.split('/').last;
        if (e is Directory && name != 'emulated' && name != 'self') roots.add(e);
      }
    } catch (_) {}
    final found = <String>[];
    for (final r in roots) {
      await _walkDir(r, known, found, 0);
    }
    return found;
  }

  Future<void> _walkDir(Directory d, Set<String> known, List<String> found, int depth) async {
    if (depth > 8) return;
    try {
      await for (final e in d.list(followLinks: false)) {
        final name = e.path.split('/').last;
        if (e is Directory) {
          if (name.startsWith('.') || name == 'Android' || name == 'LOST.DIR') continue;
          await _walkDir(e, known, found, depth + 1);
        } else if (e is File) {
          final dot = name.lastIndexOf('.');
          if (dot <= 0) continue;
          final ext = name.substring(dot + 1).toLowerCase();
          if ((_videoExt.contains(ext) || _audioExt.contains(ext)) && !known.contains(e.path)) {
            found.add(e.path);
          }
        }
      }
    } catch (_) {}
  }

  /// Returns how many files were really deleted.
  Future<int> delete(List<MediaFile> files) async {
    try {
      await PhotoManager.editor.deleteWithIds(files.map((f) => f.id).toList());
    } catch (_) {}
    final deleted = <String>{};
    final deletedPaths = <String>[];
    for (final f in files) {
      try {
        final file = File(f.path);
        if (file.existsSync()) file.deleteSync();
        if (!file.existsSync()) {
          deleted.add(f.id);
          deletedPaths.add(f.path);
          Prefs.clearPosition(f.path);
        }
      } catch (_) {}
    }
    if (deletedPaths.isNotEmpty) {
      Native.indexFiles(deletedPaths);
      PlaylistStore.instance.forget(deletedPaths);
    }
    videos.removeWhere((f) => deleted.contains(f.id));
    allAudio.removeWhere((f) => deleted.contains(f.id));
    _reindex();
    notifyListeners();
    return deleted.length;
  }
}
