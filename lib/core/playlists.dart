import 'package:flutter/foundation.dart';

import 'prefs.dart';

/// Favorites + user playlists. They store file paths so they survive rescans.
class PlaylistStore extends ChangeNotifier {
  PlaylistStore._();
  static final PlaylistStore instance = PlaylistStore._();

  List<String> favorites = <String>[];
  Map<String, List<String>> lists = <String, List<String>>{};

  void load() {
    favorites = Prefs.favorites;
    lists = Prefs.playlists;
  }

  void _save() {
    Prefs.favorites = favorites;
    Prefs.playlists = lists;
    notifyListeners();
  }

  bool isFav(String path) => favorites.contains(path);

  void toggleFav(String path) {
    if (!favorites.remove(path)) favorites.insert(0, path);
    _save();
  }

  bool create(String name) {
    final n = name.trim();
    if (n.isEmpty || lists.containsKey(n)) return false;
    lists[n] = <String>[];
    _save();
    return true;
  }

  void delete(String name) {
    lists.remove(name);
    _save();
  }

  void rename(String from, String to) {
    final n = to.trim();
    if (n.isEmpty || lists.containsKey(n) || !lists.containsKey(from)) return;
    final tracks = lists.remove(from)!;
    lists[n] = tracks;
    _save();
  }

  void addAll(String name, Iterable<String> paths) {
    final l = lists[name];
    if (l == null) return;
    for (final p in paths) {
      if (!l.contains(p)) l.add(p);
    }
    _save();
  }

  void removeFrom(String name, Iterable<String> paths) {
    lists[name]?.removeWhere((p) => paths.contains(p));
    _save();
  }

  /// Called after files were deleted from the phone.
  void forget(Iterable<String> paths) {
    final gone = paths.toSet();
    favorites.removeWhere(gone.contains);
    for (final l in lists.values) {
      l.removeWhere(gone.contains);
    }
    _save();
  }
}
