import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'home.dart';
import 'library.dart';
import 'nav.dart';
import 'settings.dart';
import 'videos.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: c.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: ShellController.tab,
        builder: (context, idx, _) => Scaffold(
          body: IndexedStack(
            index: idx,
            children: const [HomeTab(), VideosTab(), LibraryTab(), SettingsTab()],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniPlayerBar(onTap: () => openNowPlaying(context)),
              _BottomNav(index: idx, onTap: (i) => ShellController.tab.value = i),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const items = <List<Object>>[
      [Icons.home_outlined, Icons.home_rounded, 'Home'],
      [Icons.play_circle_outline_rounded, Icons.play_circle_rounded, 'Videos'],
      [Icons.library_music_outlined, Icons.library_music_rounded, 'Library'],
      [Icons.settings_outlined, Icons.settings_rounded, 'Settings'],
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (i == index ? items[i][1] : items[i][0]) as IconData,
                          color: i == index ? c.accent : c.muted,
                          size: 25,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i][2] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? c.accent : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
