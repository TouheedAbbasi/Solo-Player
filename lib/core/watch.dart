import 'library.dart';
import 'prefs.dart';

enum Watch { none, progress, done }

/// Used when a file has no known duration but the user marked it as watched.
const int _doneSentinel = 360000000;

Watch watchOf(MediaFile f) {
  final pos = Prefs.position(f.path);
  if (pos == null) return Watch.none;
  if (pos >= _doneSentinel) return Watch.done;
  final total = f.duration.inMilliseconds;
  if (total > 0 && pos >= total - 5000) return Watch.done;
  if (pos > 3000) return Watch.progress;
  return Watch.none;
}

/// 0..1 (finished episodes are 1).
double watchProgress(MediaFile f) {
  final w = watchOf(f);
  if (w == Watch.done) return 1.0;
  final pos = Prefs.position(f.path);
  final total = f.duration.inMilliseconds;
  if (pos == null || total <= 0) return 0.0;
  return (pos / total).clamp(0.0, 1.0).toDouble();
}

void markWatched(Iterable<MediaFile> files) {
  for (final f in files) {
    final ms = f.duration.inMilliseconds;
    Prefs.savePosition(f.path, ms > 0 ? ms : _doneSentinel);
  }
}

void markUnwatched(Iterable<MediaFile> files) {
  for (final f in files) {
    Prefs.clearPosition(f.path);
  }
}

class WatchStats {
  final int total;
  final int done;
  final int inProgress;
  const WatchStats(this.total, this.done, this.inProgress);
  bool get completed => total > 0 && done == total;
}

WatchStats statsOf(List<MediaFile> eps) {
  int done = 0;
  int prog = 0;
  for (final e in eps) {
    final w = watchOf(e);
    if (w == Watch.done) done++;
    if (w == Watch.progress) prog++;
  }
  return WatchStats(eps.length, done, prog);
}

/// The episode a "Continue watching" button should open.
/// [eps] must already be in watching order.
MediaFile? continueTarget(List<MediaFile> eps) {
  if (eps.isEmpty) return null;
  final recent = Prefs.recentVideo;
  MediaFile? best;
  int bestRank = 1 << 30;
  for (final e in eps) {
    if (watchOf(e) == Watch.progress) {
      final r = recent.indexOf(e.path);
      final rank = r < 0 ? (1 << 29) : r;
      if (rank < bestRank) {
        best = e;
        bestRank = rank;
      }
    }
  }
  if (best != null) return best;
  int lastDone = -1;
  for (int i = 0; i < eps.length; i++) {
    if (watchOf(eps[i]) == Watch.done) lastDone = i;
  }
  for (int i = lastDone + 1; i < eps.length; i++) {
    if (watchOf(eps[i]) == Watch.none) return eps[i];
  }
  for (final e in eps) {
    if (watchOf(e) == Watch.none) return e;
  }
  return eps.first;
}
