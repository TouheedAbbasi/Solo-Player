import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Bridge to MainActivity.kt: permissions, MediaStore scan, brightness, screen-on.
class Native {
  static const MethodChannel _c = MethodChannel('senpai/native');

  static Future<bool> requestPermission() async {
    try {
      return (await _c.invokeMethod<bool>('requestPermission')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Throws PlatformException when the query fails (e.g. no permission).
  static Future<List<Map<String, dynamic>>> scanRaw(bool video) async {
    final raw = await _c.invokeMethod<List<dynamic>>('scan', {'video': video});
    return (raw ?? <dynamic>[]).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Asks Android to add these files to MediaStore (or drop deleted ones).
  static Future<void> indexFiles(List<String> paths) async {
    try {
      await _c.invokeMethod<void>('indexFiles', {'paths': paths});
    } catch (_) {}
  }

  /// Embedded cover art of an audio file (small JPEG) or null.
  static Future<Uint8List?> audioArt(String path) async {
    try {
      return await _c.invokeMethod<Uint8List>('audioArt', {'path': path, 'size': 320});
    } catch (_) {
      return null;
    }
  }

  static Future<double> getBrightness() async {
    try {
      return (await _c.invokeMethod<double>('getBrightness')) ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setBrightness(double value) async {
    try {
      await _c.invokeMethod<void>('setBrightness', {'value': value});
    } catch (_) {}
  }

  static Future<void> resetBrightness() async {
    try {
      await _c.invokeMethod<void>('resetBrightness');
    } catch (_) {}
  }

  static Future<void> keepScreenOn(bool on) async {
    try {
      await _c.invokeMethod<void>('keepScreenOn', {'on': on});
    } catch (_) {}
  }
}
