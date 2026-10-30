import 'dart:async';

import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/theme.dart';
import 'shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
  late final Animation<double> _scale = Tween<double>(begin: 0.9, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    LibraryStore.instance.scan();
    _timer = Timer(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const Shell(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!isDark) Image.asset('assets/waves.jpg', fit: BoxFit.cover),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo_mark.png', height: 120, color: c.text),
                    const SizedBox(height: 22),
                    const Text(kAppName,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text(kTagline, style: TextStyle(fontSize: 15, color: c.muted)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                SizedBox(
                  width: 110,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _c.value,
                        minHeight: 3,
                        color: c.accent,
                        backgroundColor: c.border,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('A PRODUCT OF', style: TextStyle(fontSize: 9.5, letterSpacing: 3.5, color: c.muted)),
                const SizedBox(height: 4),
                const Text('SENPAI STUDIO',
                    style: TextStyle(fontSize: 13, letterSpacing: 5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
