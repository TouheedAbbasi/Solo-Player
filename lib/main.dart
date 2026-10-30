import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'core/playlists.dart';
import 'core/prefs.dart';
import 'core/theme.dart';
import 'screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Prefs.init();
  PlaylistStore.instance.load();
  ThemeController.mode.value = ThemeController.fromInt(Prefs.themeMode);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SoloPlayerApp());
}

class SoloPlayerApp extends StatelessWidget {
  const SoloPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: const SplashScreen(),
      ),
    );
  }
}
