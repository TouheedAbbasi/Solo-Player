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

  static String get userName => _p.getString('userName') ?? 'Touheed';
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
