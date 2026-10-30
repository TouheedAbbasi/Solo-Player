import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'about.dart';

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
      child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.8)),
    );
  }

  Widget _row(String title, {String? subtitle, String? value, VoidCallback? onTap, IconData? icon}) {
    final c = AppColors.of(context);
    return ListTile(
      leading: icon == null ? null : Icon(icon, color: c.muted),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12.5)),
      trailing: value == null
          ? Icon(Icons.chevron_right_rounded, color: c.muted)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(color: c.muted)),
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
        title: Text(title),
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
                  Expanded(child: Text(o.key, style: const TextStyle(fontSize: 16))),
                  if (o.value == current) const Icon(Icons.check_rounded),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _themeName() => const ['System', 'Light', 'Dark'][Prefs.themeMode.clamp(0, 2).toInt()];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          _header('PLAYBACK'),
          SwitchListTile(
            title: const Text('Resume playback', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Continue from where you left off'),
            value: Prefs.resume,
            onChanged: (v) => setState(() => Prefs.resume = v),
          ),
          SwitchListTile(
            title: const Text('Autoplay next video', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Play the next episode in the list automatically'),
            value: Prefs.autoNext,
            onChanged: (v) => setState(() => Prefs.autoNext = v),
          ),
          SwitchListTile(
            title: const Text('Start videos in landscape', style: TextStyle(fontWeight: FontWeight.w600)),
            value: Prefs.landscape,
            onChanged: (v) => setState(() => Prefs.landscape = v),
          ),
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
            'Your name',
            value: Prefs.userName,
            onTap: () async {
              final n = await askText(context, title: 'Your name', initial: Prefs.userName, hint: 'Shown on Home');
              if (n != null && n.trim().isNotEmpty) {
                Prefs.userName = n.trim();
                if (mounted) setState(() {});
              }
            },
          ),
          _header('LIBRARY'),
          _row(
            'Hide short audio',
            subtitle: 'Skips voice notes and tiny clips in Music',
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
                title: const Text('Scan report'),
                content: SingleChildScrollView(
                  child: SelectableText(
                    LibraryStore.instance.report.isEmpty
                        ? 'No scan has finished yet.'
                        : LibraryStore.instance.report,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close'))],
              ),
            ),
          ),
          _header('ABOUT'),
          _row(
            'About Solo Player',
            subtitle: 'Version $kVersion  ·  by $kStudio',
            icon: Icons.info_outline_rounded,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
    );
  }
}
