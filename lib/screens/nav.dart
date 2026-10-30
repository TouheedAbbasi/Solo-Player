import 'dart:math';

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/prefs.dart';
import 'now_playing.dart';
import 'video_player.dart';

/// Global UI state: selected bottom tab, library chip, and a "refresh" tick.
class ShellController {
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<int> libraryChip = ValueNotifier<int>(0);
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);
}

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()));
}

void playSongs(BuildContext context, List<MediaFile> list, int index,
    {bool open = true, bool shuffle = false}) {
  if (list.isEmpty) return;
  final a = AudioService.instance;
  a.setShuffle(shuffle);
  a.playQueue(list, shuffle ? Random().nextInt(list.length) : index);
  if (open) openNowPlaying(context);
}

Future<void> playVideos(BuildContext context, List<MediaFile> list, int index) async {
  if (list.isEmpty) return;
  Prefs.pushRecentVideo(list[index].path);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => VideoPlayerScreen(playlist: list, index: index)),
  );
  ShellController.tick.value++;
}
