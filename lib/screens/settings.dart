import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/library.dart';
import '../core/native.dart';
import '../core/strings.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'about.dart';
import 'nav.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Widget _header(String t) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Text(tr(t), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.8)),
    );
  }

  Widget _row(String title, {String? subtitle, String? value, VoidCallback? onTap, IconData? icon}) {
    final c = AppColors.of(context);
    return ListTile(
      leading: icon == null ? null : Icon(icon, color: c.muted),
      title: Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(tr(subtitle), style: TextStyle(color: c.muted, fontSize: 12.5)),
      trailing: value == null
          ? Icon(Icons.chevron_right_rounded, color: c.muted)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(value), style: TextStyle(color: c.muted)),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
      onTap: onTap,
    );
  }

  Future<void> _choose<T>({
    required String title,
    required List<MapEntry<String, T>> options,
    required T current,
    required ValueChanged<T> onPick,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(tr(title)),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialog);
                onPick(o.value);
                setState(() {});
              },
              child: Row(
                children: [
                  Expanded(child: Text(tr(o.key), style: const TextStyle(fontSize: 16))),
                  if (o.value == current) const Icon(Icons.check_rounded),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _themeName() => const ['System', 'Light', 'Dark'][Prefs.themeMode.clamp(0, 2).toInt()];

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(tr(subtitle)),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  String _subtitleSizeName() {
    final v = Prefs.subtitleSize;
    return v <= 28 ? 'Small' : (v >= 42 ? 'Large' : 'Medium');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(tr('Settings'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),

          // ───────── video library (anime friendly) ─────────
          _header('VIDEO LIBRARY'),
          _row(
            'Default view',
            subtitle: 'Folders keep every series in its own place',
            value: Prefs.videoView == 1 ? 'All videos' : 'Folders',
            onTap: () => _choose<int>(
              title: 'Default view',
              options: const [MapEntry('Folders (series)', 0), MapEntry('All videos', 1)],
              current: Prefs.videoView,
              onPick: (v) => Prefs.videoView = v,
            ),
          ),
          _row(
            'Folder order',
            value: const ['A–Z', 'Recently added', 'Last watched'][Prefs.folderSort.clamp(0, 2).toInt()],
            onTap: () => _choose<int>(
              title: 'Folder order',
              options: const [
                MapEntry('Name (A–Z)', 0),
                MapEntry('Recently added', 1),
                MapEntry('Last watched', 2),
              ],
              current: Prefs.folderSort,
              onPick: (v) => Prefs.folderSort = v,
            ),
          ),
          _row(
            'Episode order',
            subtitle: 'Episode 2 always comes before Episode 10',
            value: const ['A–Z', 'Z–A', 'Newest'][Prefs.episodeSort.clamp(0, 2).toInt()],
            onTap: () => _choose<int>(
              title: 'Episode order',
              options: const [
                MapEntry('Episode order (A–Z)', 0),
                MapEntry('Reverse order (Z–A)', 1),
                MapEntry('Newest first', 2),
              ],
              current: Prefs.episodeSort,
              onPick: (v) => Prefs.episodeSort = v,
            ),
          ),
          _switch('Show watched marks', 'Check marks and progress bars on episodes and folders',
              Prefs.showWatched, (v) => Prefs.showWatched = v),

          // ───────── playback ─────────
          _header('PLAYBACK'),
          _switch('Resume playback', 'Continue from where you left off', Prefs.resume,
              (v) => Prefs.resume = v),
          _switch('Autoplay next episode', 'Play the next video in the folder automatically',
              Prefs.autoNext, (v) => Prefs.autoNext = v),
          _switch('Start videos in landscape', 'Rotate the screen when a video starts',
              Prefs.landscape, (v) => Prefs.landscape = v),
          _switch('Keep screen on', 'Stops the screen from sleeping while a video plays',
              Prefs.keepScreenOn, (v) => Prefs.keepScreenOn = v),
          _row(
            'Default playback speed',
            value: '${Prefs.speed}x',
            onTap: () => _choose<double>(
              title: 'Default playback speed',
              options: const [
                MapEntry('0.5x', 0.5),
                MapEntry('0.75x', 0.75),
                MapEntry('1.0x (normal)', 1.0),
                MapEntry('1.25x', 1.25),
                MapEntry('1.5x', 1.5),
                MapEntry('2.0x', 2.0),
              ],
              current: Prefs.speed,
              onPick: (v) => Prefs.speed = v,
            ),
          ),

          // ───────── gestures ─────────
          _header('GESTURES'),
          _switch('Swipe for brightness and volume', 'Left side brightness, right side volume',
              Prefs.gestureBV, (v) => Prefs.gestureBV = v),
          _switch('Swipe to seek', 'Slide left or right on the video', Prefs.gestureSeek,
              (v) => Prefs.gestureSeek = v),
          _switch('Hold for 2x speed', 'Press and hold anywhere on the video', Prefs.gestureHold,
              (v) => Prefs.gestureHold = v),
          _row(
            'Double-tap seek',
            value: '${Prefs.seekStep} s',
            onTap: () => _choose<int>(
              title: 'Double-tap seek',
              options: const [
                MapEntry('5 seconds', 5),
                MapEntry('10 seconds', 10),
                MapEntry('15 seconds', 15),
                MapEntry('30 seconds', 30),
              ],
              current: Prefs.seekStep,
              onPick: (v) => Prefs.seekStep = v,
            ),
          ),

          // ───────── subtitles ─────────
          _header('SUBTITLES'),
          _switch('Auto-load subtitle files', 'Uses a .srt/.ass file with the same name as the video',
              Prefs.autoSubtitle, (v) => Prefs.autoSubtitle = v),
          _row(
            'Subtitle size',
            value: _subtitleSizeName(),
            onTap: () => _choose<int>(
              title: 'Subtitle size',
              options: const [MapEntry('Small', 26), MapEntry('Medium', 34), MapEntry('Large', 44)],
              current: Prefs.subtitleSize,
              onPick: (v) => Prefs.subtitleSize = v,
            ),
          ),

          // ───────── music ─────────
          _header('MUSIC'),
          _row(
            'Hide short audio',
            subtitle: 'Skips voice notes and tiny clips',
            value: Prefs.minAudioSec == 0 ? 'Off' : '${Prefs.minAudioSec} s',
            onTap: () => _choose<int>(
              title: 'Hide audio shorter than',
              options: const [
                MapEntry('Off', 0),
                MapEntry('15 seconds', 15),
                MapEntry('30 seconds', 30),
                MapEntry('60 seconds', 60),
              ],
              current: Prefs.minAudioSec,
              onPick: (v) {
                Prefs.minAudioSec = v;
                LibraryStore.instance.refreshIndex();
              },
            ),
          ),

          _switch('Music notification', 'Play, pause and skip buttons in the notification bar',
              Prefs.mediaNotification, (v) {
            Prefs.mediaNotification = v;
            if (v) {
              AudioService.instance.refreshNotification();
            } else {
              Native.mediaHide();
            }
          }),

          // ───────── appearance ─────────
          _header('APPEARANCE'),
          _row(
            'Theme',
            value: _themeName(),
            onTap: () => _choose<int>(
              title: 'Theme',
              options: const [MapEntry('System', 0), MapEntry('Light', 1), MapEntry('Dark', 2)],
              current: Prefs.themeMode,
              onPick: (v) {
                Prefs.themeMode = v;
                ThemeController.mode.value = ThemeController.fromInt(v);
              },
            ),
          ),
          _row(
            'Language',
            value: Prefs.language == 'ur' ? 'اردو' : 'English',
            onTap: () => _choose<String>(
              title: 'Language',
              options: const [MapEntry('English', 'en'), MapEntry('اردو (Urdu)', 'ur')],
              current: Prefs.language,
              onPick: (v) {
                Prefs.language = v;
                Lang.code.value = v;
              },
            ),
          ),
          _row(
            'Your name',
            value: Prefs.userName.isEmpty ? 'Not set' : Prefs.userName,
            onTap: () async {
              final n = await askText(context, title: 'Your name', initial: Prefs.userName, hint: 'Shown on Home');
              if (n != null) {
                Prefs.userName = n.trim();
                ShellController.tick.value++;
                if (mounted) setState(() {});
              }
            },
          ),

          // ───────── storage ─────────
          _header('STORAGE'),
          _row(
            'Rescan media',
            subtitle: 'Look for new videos and music on your phone',
            icon: Icons.refresh_rounded,
            onTap: () {
              LibraryStore.instance.scan(silent: true);
              toast(context, 'Scanning…');
            },
          ),
          _row(
            'Scan report',
            subtitle: 'What the scan found (useful if files are missing)',
            icon: Icons.bug_report_outlined,
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: Text(tr('Scan report')),
                content: SingleChildScrollView(
                  child: SelectableText(
                    LibraryStore.instance.report.isEmpty
                        ? 'No scan has finished yet.'
                        : LibraryStore.instance.report,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: Text(tr('Close')))],
              ),
            ),
          ),

          _row(
            'Clear watch history',
            subtitle: 'Removes watched marks, resume positions and recent lists',
            icon: Icons.history_toggle_off_rounded,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: Text(tr('Clear watch history?')),
                  content: Text(tr('Your videos and music are not deleted.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr('Cancel'))),
                    TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tr('Clear'))),
                  ],
                ),
              );
              if (ok == true) {
                Prefs.clearHistory();
                ShellController.tick.value++;
                if (mounted) toast(context, 'History cleared');
              }
            },
          ),
          _row(
            'Clear search history',
            icon: Icons.manage_search_rounded,
            onTap: () {
              Prefs.recentSearches = <String>[];
              toast(context, 'Search history cleared');
            },
          ),

          // ───────── about ─────────
          _header('ABOUT'),
          _row(
            'About Solo Player',
            subtitle: tn('Version {v}  ·  by {s}', {'v': kVersion, 's': kStudio}),
            icon: Icons.info_outline_rounded,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }
}
