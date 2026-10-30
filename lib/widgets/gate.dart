import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/library.dart';
import '../core/theme.dart';

/// Shows a spinner while scanning, a permission prompt when access is denied,
/// otherwise the real content.
class StoreGate extends StatelessWidget {
  final WidgetBuilder builder;
  const StoreGate({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final store = LibraryStore.instance;
    switch (store.state) {
      case ScanState.idle:
      case ScanState.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: c.accent),
              const SizedBox(height: 16),
              Text('Scanning your media…', style: TextStyle(color: c.muted)),
            ],
          ),
        );
      case ScanState.denied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: c.accent),
                const SizedBox(height: 16),
                const Text('Storage permission needed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Solo Player needs access to your videos and music to show them here. Nothing ever leaves your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
                  onPressed: () => store.scan(),
                  child: const Text('Allow access'),
                ),
                TextButton(
                  onPressed: () => PhotoManager.openSetting(),
                  child: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        );
      case ScanState.ready:
        return builder(context);
    }
  }
}
