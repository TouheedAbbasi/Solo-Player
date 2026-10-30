import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/native.dart';
import '../core/prefs.dart';
import '../widgets/common.dart';

const List<BoxFit> _fits = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
const List<String> _fitNames = ['Fit', 'Crop', 'Stretch'];

final SubtitleViewConfiguration _subCfg = SubtitleViewConfiguration(
  style: const TextStyle(
    fontSize: 34,
    color: Colors.white,
    fontWeight: FontWeight.w500,
    backgroundColor: Color(0x99000000),
  ),
  padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
);

class _Hud {
  final IconData icon;
  final String text;
  const _Hud(this.icon, this.text);
}

class _Opt {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Opt(this.label, this.selected, this.onTap);
}

/// The video surface lives in its own widget and is created only once.
/// Nothing else on screen (HUD, controls, sliders) is allowed to rebuild it,
/// which is what removes the flicker.
class _VideoSurface extends StatelessWidget {
  final VideoController controller;
  final ValueListenable<int> fit;
  const _VideoSurface({required this.controller, required this.fit});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: fit,
        builder: (context, f, _) => Video(
          controller: controller,
          fit: _fits[f],
          controls: NoVideoControls,
          subtitleViewConfiguration: _subCfg,
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final List<MediaFile> playlist;
  final int index;
  const VideoPlayerScreen({super.key, required this.playlist, required this.index});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late final Widget _surface;

  late final ValueNotifier<int> _index = ValueNotifier<int>(widget.index);
  final ValueNotifier<bool> _controls = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _locked = ValueNotifier<bool>(false);
  final ValueNotifier<int> _fit = ValueNotifier<int>(0);
  final ValueNotifier<_Hud?> _hud = ValueNotifier<_Hud?>(null);
  final ValueNotifier<double?> _drag = ValueNotifier<double?>(null);

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _hideTimer;
  Timer? _hudTimer;

  double _speed = Prefs.speed;
  double _brightness = 0.5;
  double _volume = 100;

  Offset _tapPos = Offset.zero;
  Duration _hStart = Duration.zero;
  Duration _hTarget = Duration.zero;
  double _hDx = 0;
  bool _hActive = false;
  bool _vLeft = true;
  double _vAccum = 0;
  double _vStartBrightness = 0.5;
  double _vStartVolume = 100;
  double _speedBefore = 1.0;

  MediaFile get _file => widget.playlist[_index.value];

  @override
  void initState() {
    super.initState();
    _surface = _VideoSurface(controller: _video, fit: _fit);
    AudioService.instance.player.pause();
    Native.keepScreenOn(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(Prefs.landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : DeviceOrientation.values);
    _initBrightness();
    _subs.add(_player.stream.completed.listen((c) {
      if (c) _onCompleted();
    }));
    _open();
    _scheduleHide();
  }

  Future<void> _initBrightness() async {
    _brightness = await Native.getBrightness();
  }

  // ───────── playback ─────────
  Future<void> _open() async {
    final f = _file;
    Prefs.pushRecentVideo(f.path);
    await _player.open(Media(f.path), play: false);
    final saved = Prefs.resume ? Prefs.position(f.path) : null;
    if (saved != null &&
        saved > 3000 &&
        (f.duration == Duration.zero || f.duration.inMilliseconds - saved > 5000)) {
      if (_player.state.duration == Duration.zero) {
        await _player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 6), onTimeout: () => Duration.zero);
      }
      await _player.seek(Duration(milliseconds: saved));
      if (mounted) _showHud(Icons.history_rounded, 'Resumed ${fmtDur(Duration(milliseconds: saved))}');
    }
    await _player.setRate(_speed);
    await _player.play();
    _autoSubtitle(f);
  }

  void _autoSubtitle(MediaFile f) {
    final dot = f.path.lastIndexOf('.');
    if (dot <= 0) return;
    final base = f.path.substring(0, dot);
    for (final e in const ['srt', 'ass', 'ssa', 'vtt']) {
      final p = '$base.$e';
      try {
        if (File(p).existsSync()) {
          _player.setSubtitleTrack(SubtitleTrack.uri(p, title: 'External ($e)'));
          return;
        }
      } catch (_) {}
    }
  }

  void _save() {
    final p = _player.state.position;
    final d = _player.state.duration;
    if (d.inSeconds <= 0) return;
    if (d.inMilliseconds - p.inMilliseconds < 5000) {
      Prefs.savePosition(_file.path, d.inMilliseconds);
    } else if (p.inSeconds >= 3) {
      Prefs.savePosition(_file.path, p.inMilliseconds);
    }
  }

  void _onCompleted() {
    if (!mounted) return;
    final d = _player.state.duration.inMilliseconds;
    Prefs.savePosition(_file.path, d > 0 ? d : _file.duration.inMilliseconds);
    if (Prefs.autoNext && _index.value < widget.playlist.length - 1) {
      _index.value++;
      _open();
    } else {
      _controls.value = true;
    }
  }

  void _go(int delta) {
    final n = _index.value + delta;
    if (n < 0 || n >= widget.playlist.length) return;
    _save();
    _index.value = n;
    _open();
  }

  void _skip(int secs) {
    final dur = _player.state.duration.inMilliseconds;
    var ms = _player.state.position.inMilliseconds + secs * 1000;
    if (ms < 0) ms = 0;
    if (dur > 0 && ms > dur) ms = dur;
    _player.seek(Duration(milliseconds: ms));
    _showHud(secs > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
        '${secs > 0 ? '+' : ''}$secs s');
  }

  // ───────── HUD / controls visibility ─────────
  void _showHud(IconData icon, String text, {int ms = 900}) {
    _hudTimer?.cancel();
    _hud.value = _Hud(icon, text);
    _hudTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) _hud.value = null;
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) _controls.value = false;
    });
  }

  void _toggleControls() {
    _controls.value = !_controls.value;
    if (_controls.value) _scheduleHide();
  }

  // ───────── gestures ─────────
  void _onDoubleTap() {
    if (_locked.value) return;
    final w = MediaQuery.of(context).size.width;
    if (_tapPos.dx < w / 3) {
      _skip(-Prefs.seekStep);
    } else if (_tapPos.dx > w * 2 / 3) {
      _skip(Prefs.seekStep);
    } else {
      _player.playOrPause();
    }
  }

  void _hDragStart(DragStartDetails d) {
    if (_locked.value) return;
    _hActive = true;
    _hDx = 0;
    _hStart = _player.state.position;
    _hTarget = _hStart;
  }

  void _hDragUpdate(DragUpdateDetails d) {
    if (!_hActive) return;
    _hDx += d.delta.dx;
    final offsetSecs = (_hDx / 5).round();
    final dur = _player.state.duration.inMilliseconds;
    var ms = _hStart.inMilliseconds + offsetSecs * 1000;
    if (ms < 0) ms = 0;
    if (dur > 0 && ms > dur) ms = dur;
    _hTarget = Duration(milliseconds: ms);
    _showHud(offsetSecs >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
        '${fmtDur(_hTarget)}  (${offsetSecs >= 0 ? '+' : ''}$offsetSecs s)',
        ms: 1200);
  }

  void _hDragEnd(DragEndDetails d) {
    if (!_hActive) return;
    _hActive = false;
    _player.seek(_hTarget);
  }

  void _vDragStart(DragStartDetails d) {
    if (_locked.value) return;
    _vLeft = d.localPosition.dx < MediaQuery.of(context).size.width / 2;
    _vAccum = 0;
    _vStartBrightness = _brightness;
    _vStartVolume = _volume;
  }

  void _vDragUpdate(DragUpdateDetails d) {
    if (_locked.value) return;
    _vAccum -= d.delta.dy;
    final h = MediaQuery.of(context).size.height;
    final frac = _vAccum / (h * 0.7);
    if (_vLeft) {
      _brightness = (_vStartBrightness + frac).clamp(0.0, 1.0).toDouble();
      Native.setBrightness(_brightness);
      _showHud(Icons.brightness_6_rounded, '${(_brightness * 100).round()}%', ms: 800);
    } else {
      _volume = (_vStartVolume + frac * 100).clamp(0.0, 100.0).toDouble();
      _player.setVolume(_volume);
      _showHud(_volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          '${_volume.round()}%',
          ms: 800);
    }
  }

  // ───────── sheets ─────────
  void _sheet(String title, List<_Opt> opts) {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1F),
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in opts)
                    ListTile(
                      dense: true,
                      title: Text(o.label, style: const TextStyle(color: Colors.white)),
                      trailing: o.selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                      onTap: () {
                        Navigator.pop(sheet);
                        o.onTap();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) _scheduleHide();
    });
  }

  String _trackLabel(String id, String? title, String? lang) {
    if (id == 'auto') return 'Auto';
    if (id == 'no') return 'Off';
    final parts = <String>[
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty) lang.toUpperCase(),
    ];
    return parts.isEmpty ? 'Track $id' : parts.join('  ·  ');
  }

  void _pickAudio() {
    final tracks = _player.state.tracks.audio;
    final cur = _player.state.track.audio;
    _sheet('Audio track', [
      for (final t in tracks)
        _Opt(_trackLabel(t.id, t.title, t.language), t.id == cur.id, () => _player.setAudioTrack(t)),
    ]);
  }

  void _pickSubtitle() {
    final tracks = _player.state.tracks.subtitle;
    final cur = _player.state.track.subtitle;
    _sheet('Subtitles', [
      for (final t in tracks)
        _Opt(_trackLabel(t.id, t.title, t.language), t.id == cur.id, () => _player.setSubtitleTrack(t)),
      _Opt('Load from file…', false, _loadSubFile),
    ]);
  }

  Future<void> _loadSubFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'ass', 'ssa', 'vtt'],
    );
    if (r == null || r.files.isEmpty) return;
    final p = r.files.single.path;
    if (p == null) return;
    await _player.setSubtitleTrack(SubtitleTrack.uri(p, title: r.files.single.name));
    if (mounted) _showHud(Icons.subtitles_rounded, 'Subtitle loaded');
  }

  void _pickSpeed() {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    _sheet('Playback speed', [
      for (final r in rates)
        _Opt('${r}x', r == _speed, () {
          _speed = r;
          _player.setRate(r);
          _showHud(Icons.speed_rounded, '${r}x');
        }),
    ]);
  }

  void _rotate() {
    final portrait = MediaQuery.of(context).orientation == Orientation.portrait;
    SystemChrome.setPreferredOrientations(portrait
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  void _cycleFit() {
    _fit.value = (_fit.value + 1) % _fits.length;
    _showHud(Icons.aspect_ratio_rounded, _fitNames[_fit.value]);
  }

  @override
  void dispose() {
    _save();
    for (final s in _subs) {
      s.cancel();
    }
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _player.dispose();
    Native.keepScreenOn(false);
    Native.resetBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _index.dispose();
    _controls.dispose();
    _locked.dispose();
    _fit.dispose();
    _hud.dispose();
    _drag.dispose();
    super.dispose();
  }

  // ───────── build ─────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _locked,
      builder: (context, locked, child) => PopScope(canPop: !locked, child: child!),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _surface,
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTapDown: (d) => _tapPos = d.localPosition,
              onDoubleTap: _onDoubleTap,
              onLongPressStart: (_) {
                if (_locked.value) return;
                _speedBefore = _speed;
                _player.setRate(2.0);
                _showHud(Icons.fast_forward_rounded, '2x speed', ms: 60000);
              },
              onLongPressEnd: (_) {
                _player.setRate(_speedBefore);
                _hud.value = null;
              },
              onHorizontalDragStart: _hDragStart,
              onHorizontalDragUpdate: _hDragUpdate,
              onHorizontalDragEnd: _hDragEnd,
              onVerticalDragStart: _vDragStart,
              onVerticalDragUpdate: _vDragUpdate,
              child: const SizedBox.expand(),
            ),
            StreamBuilder<bool>(
              stream: _player.stream.buffering,
              initialData: false,
              builder: (context, s) => (s.data ?? false)
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : const SizedBox.shrink(),
            ),
            ValueListenableBuilder<_Hud?>(
              valueListenable: _hud,
              builder: (context, h, _) => h == null ? const SizedBox.shrink() : _hudView(h),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_controls, _locked]),
              builder: (context, _) {
                if (!_controls.value) return const SizedBox.shrink();
                if (_locked.value) return _unlockButton();
                return Column(
                  children: [
                    _topBar(),
                    const Spacer(),
                    _bottomBar(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudView(_Hud h) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(h.icon, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Text(h.text,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unlockButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xB3000000), shape: BoxShape.circle),
          child: IconButton(
            iconSize: 30,
            icon: const Icon(Icons.lock_rounded, color: Colors.white),
            onPressed: () {
              _locked.value = false;
              _showHud(Icons.lock_open_rounded, 'Unlocked');
              _scheduleHide();
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _index,
                builder: (context, i, _) => Text(
                  widget.playlist[i].niceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Subtitles',
              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
              onPressed: _pickSubtitle,
            ),
            IconButton(
              tooltip: 'Audio track',
              icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
              onPressed: _pickAudio,
            ),
            IconButton(
              tooltip: 'Speed',
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              onPressed: _pickSpeed,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (v) {
                if (v == 'info') showInfo(context, _file);
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(value: 'info', child: Text('Properties')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final res = resLabel(_file.height);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seekRow(),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Lock',
                    icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                    onPressed: () {
                      _locked.value = true;
                      _controls.value = true;
                      _showHud(Icons.lock_rounded, 'Screen locked');
                      _scheduleHide();
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _index,
                    builder: (context, i, _) => Row(
                      children: [
                        IconButton(
                          iconSize: 34,
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                          onPressed: i > 0 ? () => _go(-1) : null,
                        ),
                        const SizedBox(width: 6),
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          initialData: _player.state.playing,
                          builder: (context, s) {
                            final playing = s.data ?? false;
                            return Container(
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: IconButton(
                                iconSize: 38,
                                icon: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: const Color(0xFF1F1F1F),
                                ),
                                onPressed: () {
                                  _player.playOrPause();
                                  _scheduleHide();
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          iconSize: 34,
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                          onPressed: i < widget.playlist.length - 1 ? () => _go(1) : null,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (res.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(res, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                        ),
                      IconButton(
                        tooltip: 'Aspect ratio',
                        icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                        onPressed: _cycleFit,
                      ),
                      IconButton(
                        tooltip: 'Rotate',
                        icon: const Icon(Icons.screen_rotation_rounded, color: Colors.white),
                        onPressed: _rotate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seekRow() {
    return StreamBuilder<Duration>(
      stream: _player.stream.duration,
      initialData: _player.state.duration,
      builder: (context, ds) {
        final dur = ds.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.stream.position,
          initialData: _player.state.position,
          builder: (context, ps) {
            final pos = ps.data ?? Duration.zero;
            final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
            return ValueListenableBuilder<double?>(
              valueListenable: _drag,
              builder: (context, drag, _) {
                final value = (drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Text(fmtDur(Duration(milliseconds: value.round())),
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: value,
                            max: max,
                            onChangeStart: (_) => _hideTimer?.cancel(),
                            onChanged: (v) => _drag.value = v,
                            onChangeEnd: (v) {
                              _player.seek(Duration(milliseconds: v.round()));
                              _drag.value = null;
                              _scheduleHide();
                            },
                          ),
                        ),
                      ),
                      Text(fmtDur(dur), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
