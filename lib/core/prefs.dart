import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ───────── settings ─────────
  static bool get resume => _p.getBool('resume') ?? true;
  static set resume(bool v) {
    _p.setBool('resume', v);
  }

  static bool get autoNext => _p.getBool('autoNext') ?? true;
  static set autoNext(bool v) {
    _p.setBool('autoNext', v);
  }

  static bool get landscape => _p.getBool('landscape') ?? true;
  static set landscape(bool v) {
    _p.setBool('landscape', v);
  }

  static int get seekStep => _p.getInt('seekStep') ?? 10;
  static set seekStep(int v) {
    _p.setInt('seekStep', v);
  }

  static double get speed => _p.getDouble('speed') ?? 1.0;
  static set speed(double v) {
    _p.setDouble('speed', v);
  }

  static int get themeMode => _p.getInt('themeMode') ?? 0;
  static set themeMode(int v) {
    _p.setInt('themeMode', v);
  }

  static String get userName => _p.getString('userName') ?? '';
  static set userName(String v) {
    _p.setString('userName', v);
  }

  static int get minAudioSec => _p.getInt('minAudioSec') ?? 15;
  static set minAudioSec(int v) {
    _p.setInt('minAudioSec', v);
  }

  static int get sort => _p.getInt('sort') ?? 1;
  static set sort(int v) {
    _p.setInt('sort', v);
  }

  // ───────── app ─────────
  /// 'en' or 'ur'
  static String get language => _p.getString('language') ?? 'en';
  static set language(String v) {
    _p.setString('language', v);
  }

  static bool get mediaNotification => _p.getBool('mediaNotification') ?? true;
  static set mediaNotification(bool v) {
    _p.setBool('mediaNotification', v);
  }

  static bool get keepScreenOn => _p.getBool('keepScreenOn') ?? true;
  static set keepScreenOn(bool v) {
    _p.setBool('keepScreenOn', v);
  }

  static bool get folderGrid => _p.getBool('folderGrid') ?? true;
  static set folderGrid(bool v) {
    _p.setBool('folderGrid', v);
  }

  static bool get askedNotification => _p.getBool('askedNotification') ?? false;
  static set askedNotification(bool v) {
    _p.setBool('askedNotification', v);
  }

  /// Forgets watched marks, resume positions and "recently played" lists.
  static void clearHistory() {
    for (final k in _p.getKeys().toList()) {
      if (k.startsWith('pos:')) _p.remove(k);
    }
    _p.remove('recentAudio');
    _p.remove('recentVideo');
  }

  // ───────── video library ─────────
  /// 0 = folders (series), 1 = all videos
  static int get videoView => _p.getInt('videoView') ?? 0;
  static set videoView(int v) {
    _p.setInt('videoView', v);
  }

  /// 0 = name, 1 = recently added, 2 = last watched
  static int get folderSort => _p.getInt('folderSort') ?? 0;
  static set folderSort(int v) {
    _p.setInt('folderSort', v);
  }

  /// 0 = natural A-Z (Episode 2 before Episode 10), 1 = Z-A, 2 = newest first
  static int get episodeSort => _p.getInt('episodeSort') ?? 0;
  static set episodeSort(int v) {
    _p.setInt('episodeSort', v);
  }

  static bool get showWatched => _p.getBool('showWatched') ?? true;
  static set showWatched(bool v) {
    _p.setBool('showWatched', v);
  }

  // ───────── gestures ─────────
  static bool get gestureBV => _p.getBool('gestureBV') ?? true;
  static set gestureBV(bool v) {
    _p.setBool('gestureBV', v);
  }

  static bool get gestureSeek => _p.getBool('gestureSeek') ?? true;
  static set gestureSeek(bool v) {
    _p.setBool('gestureSeek', v);
  }

  static bool get gestureHold => _p.getBool('gestureHold') ?? true;
  static set gestureHold(bool v) {
    _p.setBool('gestureHold', v);
  }

  // ───────── subtitles ─────────
  static bool get autoSubtitle => _p.getBool('autoSubtitle') ?? true;
  static set autoSubtitle(bool v) {
    _p.setBool('autoSubtitle', v);
  }

  static int get subtitleSize => _p.getInt('subtitleSize') ?? 34;
  static set subtitleSize(int v) {
    _p.setInt('subtitleSize', v);
  }

  // ───────── lists ─────────
  static List<String> _list(String k) => _p.getStringList(k) ?? <String>[];

  static List<String> get recentSearches => _list('recentSearches');
  static set recentSearches(List<String> v) {
    _p.setStringList('recentSearches', v);
  }

  static void addSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    final l = recentSearches..remove(t);
    l.insert(0, t);
    recentSearches = l.take(8).toList();
  }

  static List<String> get recentAudio => _list('recentAudio');
  static void pushRecentAudio(String path) {
    final l = recentAudio..remove(path);
    l.insert(0, path);
    _p.setStringList('recentAudio', l.take(20).toList());
  }

  static List<String> get recentVideo => _list('recentVideo');
  static void pushRecentVideo(String path) {
    final l = recentVideo..remove(path);
    l.insert(0, path);
    _p.setStringList('recentVideo', l.take(20).toList());
  }

  static List<String> get favorites => _list('favorites');
  static set favorites(List<String> v) {
    _p.setStringList('favorites', v);
  }

  static Map<String, List<String>> get playlists {
    final raw = _p.getString('playlists');
    if (raw == null) return <String, List<String>>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static set playlists(Map<String, List<String>> v) {
    _p.setString('playlists', jsonEncode(v));
  }

  // ───────── watch history ─────────
  static int? position(String path) => _p.getInt('pos:$path');

  static void savePosition(String path, int ms) {
    _p.setInt('pos:$path', ms);
  }

  static void clearPosition(String path) {
    _p.remove('pos:$path');
  }
}
