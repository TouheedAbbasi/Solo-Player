import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'library.dart';
import 'native.dart';
import 'prefs.dart';

/// One global audio player so music keeps playing while you browse the app.
/// It also drives the music notification (title, cover, previous / play / next).
class AudioService extends ChangeNotifier {
  AudioService._() {
    player.stream.completed.listen((done) {
      if (done) _onCompleted();
    });
    player.stream.playing.listen((_) {
      notifyListeners();
      _pushNotification();
    });
    player.stream.duration.listen((_) => _pushNotification());
    Native.listenMediaActions(_onMediaAction);
  }
  static final AudioService instance = AudioService._();

  final Player player = Player();
  final Random _rng = Random();

  List<MediaFile> queue = [];
  int index = -1;
  bool shuffle = false;
  int repeat = 0; // 0 = off, 1 = all, 2 = one
  double speed = Prefs.speed;
  Timer? _sleep;
  DateTime? sleepEnd;

  String? _artPath;
  Uint8List? _art;

  MediaFile? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  bool get playing => player.state.playing;

  Future<void> playQueue(List<MediaFile> list, int start) async {
    if (list.isEmpty) return;
    queue = List<MediaFile>.of(list);
    index = max(0, min(start, list.length - 1));
    if (!Prefs.askedNotification) {
      Prefs.askedNotification = true;
      Native.requestNotificationPermission();
    }
    await _open();
  }

  Future<void> _open() async {
    final c = current;
    if (c == null) return;
    Prefs.pushRecentAudio(c.path);
    await player.open(Media(c.path), play: true);
    await player.setRate(speed);
    notifyListeners();
    _pushNotification();
  }

  Future<void> seek(Duration d) async {
    await player.seek(d);
    _pushNotification();
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= queue.length) return;
    index = i;
    await _open();
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (shuffle && queue.length > 1) {
      int n;
      do {
        n = _rng.nextInt(queue.length);
      } while (n == index);
      index = n;
    } else if (index < queue.length - 1) {
      index++;
    } else if (repeat == 1 || !auto) {
      index = 0;
    } else {
      await player.pause();
      await player.seek(Duration.zero);
      notifyListeners();
      return;
    }
    await _open();
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (player.state.position.inSeconds > 3 || index == 0) {
      await seek(Duration.zero);
      return;
    }
    index--;
    await _open();
  }

  void _onCompleted() {
    if (repeat == 2) {
      player.seek(Duration.zero);
      player.play();
    } else {
      next(auto: true);
    }
  }

  // ───────── notification ─────────
  void refreshNotification() => _pushNotification();

  Future<void> _pushNotification() async {
    final c = current;
    if (c == null || !Prefs.mediaNotification) return;
    if (_artPath != c.path) {
      _artPath = c.path;
      _art = await Native.audioArt(c.path);
      if (current?.path != c.path) return; // track changed while loading art
    }
    final st = player.state;
    final dur = st.duration.inMilliseconds > 0 ? st.duration.inMilliseconds : c.duration.inMilliseconds;
    await Native.mediaUpdate(
      title: c.niceTitle,
      artist: c.artist,
      playing: st.playing,
      position: st.position.inMilliseconds,
      duration: dur,
      speed: speed,
      art: _art,
    );
  }

  void _onMediaAction(String action) {
    if (action == 'playpause') {
      player.playOrPause();
    } else if (action == 'next') {
      next();
    } else if (action == 'prev') {
      previous();
    } else if (action == 'stop') {
      stop();
    } else if (action.startsWith('seek:')) {
      final ms = int.tryParse(action.substring(5));
      if (ms != null) seek(Duration(milliseconds: ms));
    }
  }

  // ───────── queue editing ─────────
  void playNext(MediaFile f) {
    if (queue.isEmpty) {
      playQueue([f], 0);
      return;
    }
    queue.insert(index + 1, f);
    notifyListeners();
  }

  void addToQueue(MediaFile f) {
    if (queue.isEmpty) {
      playQueue([f], 0);
      return;
    }
    queue.add(f);
    notifyListeners();
  }

  void removeAt(int i) {
    if (i < 0 || i >= queue.length || i == index) return;
    queue.removeAt(i);
    if (i < index) index--;
    notifyListeners();
  }

  // ───────── modes ─────────
  void setShuffle(bool v) {
    shuffle = v;
    notifyListeners();
  }

  void toggleShuffle() => setShuffle(!shuffle);

  void cycleRepeat() {
    repeat = (repeat + 1) % 3;
    notifyListeners();
  }

  Future<void> setSpeed(double s) async {
    speed = s;
    await player.setRate(s);
    notifyListeners();
    _pushNotification();
  }

  void setSleep(Duration? d) {
    _sleep?.cancel();
    sleepEnd = null;
    if (d != null) {
      sleepEnd = DateTime.now().add(d);
      _sleep = Timer(d, () {
        player.pause();
        sleepEnd = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await player.pause();
    queue = [];
    index = -1;
    _artPath = null;
    _art = null;
    notifyListeners();
    Native.mediaHide();
  }
}
