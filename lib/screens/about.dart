import 'package:flutter/material.dart';

import '../core/theme.dart';

const String _privacy = '''Solo Player works completely offline.

What the app does
• It reads the videos and music stored on your phone so it can list and play them.
• It saves your settings, playlists, favorites and playback positions on your phone only.

What the app does NOT do
• It does not collect, upload or share any personal data.
• It does not contain ads or trackers.
• It does not need an internet connection.

Permissions
• Storage / Media access: to find and play your videos and music, and to delete files when you ask it to.

Deleting files
Files are deleted only after you confirm. Deleted files cannot be restored by the app.

Contact
Solo Player is a product of Senpai Studio. Developed by Touheed Abbasi.''';

const String _terms = '''By using Solo Player you agree to the following.

1. Solo Player is provided "as is", without any warranty.
2. You are responsible for the files you play and delete. Deleted files cannot be recovered by the app.
3. Please only play media that you have the right to use.
4. Senpai Studio is not liable for any loss or damage resulting from the use of this app.
5. These terms may change in future versions of the app.

© 2026 Senpai Studio. All rights reserved.''';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: c.muted),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
          onTap: onTap,
        );

    void open(String title, String body) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LegalScreen(title: title, body: body)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          const SizedBox(height: 18),
          Center(child: Image.asset('assets/logo_mark.png', height: 84, color: c.text)),
          const SizedBox(height: 16),
          const Center(
            child: Text(kAppName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Center(child: Text('Version $kVersion', style: TextStyle(color: c.muted))),
          const SizedBox(height: 4),
          Center(child: Text(kTagline, style: TextStyle(color: c.muted))),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SENPAI STUDIO',
                      style: TextStyle(fontSize: 12.5, letterSpacing: 4, color: c.muted, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                    'Solo Player is a fast, private and completely offline media player for people who just want their videos and music to play. MKV, MP4, subtitles, playlists and gestures, with no ads and no tracking.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          item(Icons.shield_outlined, 'Privacy Policy', () => open('Privacy Policy', _privacy)),
          item(Icons.description_outlined, 'Terms & Conditions', () => open('Terms & Conditions', _terms)),
          const SizedBox(height: 28),
          Center(
            child: Text('Developed by Touheed Abbasi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('© 2026 Senpai Studio. All rights reserved.',
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ],
      ),
    );
  }
}
