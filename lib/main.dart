import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'core/playlists.dart';
import 'core/prefs.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/shell.dart';
import 'screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Prefs.init();
  PlaylistStore.instance.load();
  ThemeController.mode.value = ThemeController.fromInt(Prefs.themeMode);
  Lang.code.value = Prefs.language;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SoloPlayerApp());
}

class SoloPlayerApp extends StatelessWidget {
  const SoloPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeController.mode, Lang.code]),
      builder: (context, _) => MaterialApp(
        // A new key per language rebuilds every screen so all texts are re-translated.
        key: ValueKey<String>(Lang.code.value),
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeController.mode.value,
        locale: Locale(Lang.code.value),
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Boot.done ? const Shell() : const SplashScreen(),
      ),
    );
  }
}
