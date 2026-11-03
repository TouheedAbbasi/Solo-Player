import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/strings.dart';

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
• Notifications: to show the music controls while a song is playing.

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

const String _privacyUr = '''سولو پلیئر مکمل طور پر آف لائن کام کرتا ہے۔

ایپ کیا کرتی ہے
• یہ آپ کے فون میں موجود ویڈیوز اور موسیقی کو فہرست بنانے اور چلانے کے لیے پڑھتی ہے۔
• یہ آپ کی سیٹنگز، پلے لسٹس، پسندیدہ اور پلے بیک کی جگہیں صرف آپ کے فون میں محفوظ کرتی ہے۔

ایپ کیا نہیں کرتی
• یہ کوئی ذاتی ڈیٹا جمع، اپ لوڈ یا شیئر نہیں کرتی۔
• اس میں اشتہارات یا ٹریکرز نہیں ہیں۔
• اسے انٹرنیٹ کی ضرورت نہیں۔

اجازتیں
• اسٹوریج / میڈیا تک رسائی: آپ کی ویڈیوز اور موسیقی تلاش کرنے اور چلانے کے لیے، اور آپ کے کہنے پر فائلیں ڈیلیٹ کرنے کے لیے۔
• نوٹیفکیشن: گانا چلتے وقت میوزک کنٹرول دکھانے کے لیے۔

فائلیں ڈیلیٹ کرنا
فائلیں صرف آپ کی تصدیق کے بعد ڈیلیٹ ہوتی ہیں۔ ڈیلیٹ شدہ فائلیں ایپ واپس نہیں لا سکتی۔

رابطہ
سولو پلیئر سینپائی اسٹوڈیو کی پروڈکٹ ہے۔ ڈویلپر: توحید عباسی۔''';

const String _termsUr = '''سولو پلیئر استعمال کرنے سے آپ درج ذیل سے اتفاق کرتے ہیں۔

1. سولو پلیئر "جیسا ہے" کی بنیاد پر، بغیر کسی ضمانت کے فراہم کیا گیا ہے۔
2. آپ اپنی چلائی اور ڈیلیٹ کی گئی فائلوں کے خود ذمہ دار ہیں۔ ڈیلیٹ شدہ فائلیں ایپ واپس نہیں لا سکتی۔
3. براہ کرم صرف وہی میڈیا چلائیں جسے استعمال کرنے کا آپ کو حق ہے۔
4. اس ایپ کے استعمال سے ہونے والے کسی نقصان کی ذمہ داری سینپائی اسٹوڈیو پر نہیں۔
5. یہ شرائط ایپ کے آئندہ ورژنز میں تبدیل ہو سکتی ہیں۔

© 2026 سینپائی اسٹوڈیو۔ جملہ حقوق محفوظ ہیں۔''';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(title))),
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
          title: Text(tr(label), style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
          onTap: onTap,
        );

    void open(String title, String body) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LegalScreen(title: title, body: body)),
        );

    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Text(tr(label), style: TextStyle(fontSize: 12.5, color: c.text, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(tr('About'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          const SizedBox(height: 10),
          Center(child: Image.asset('assets/logo_lockup.png', height: 150, color: c.text)),
          const SizedBox(height: 6),
          Center(child: Text('Version $kVersion', style: TextStyle(color: c.muted))),
          const SizedBox(height: 22),

          // ───────── developer card ─────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: c.accent,
                    child: Text(tr('TA'),
                        style: TextStyle(
                            color: c.onAccent, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 14),
                  Text(tr('Touheed Abbasi'),
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(tr('Developer & Designer'), style: TextStyle(color: c.muted, fontSize: 14)),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(Icons.school_outlined, 'Software Engineering Student'),
                      chip(Icons.brush_outlined, kStudio),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(tr('Solo Player was designed and built by Touheed for people who love their videos and music, especially anime fans who want every series neatly in its own folder.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, height: 1.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ───────── studio ─────────
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
                  Text(tr('SENPAI STUDIO'),
                      style: TextStyle(fontSize: 12.5, letterSpacing: 4, color: c.muted, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(tr('Fast, private and completely offline. MKV and MP4 playback, subtitles, playlists, gestures and a clean design. No ads. No tracking.'),
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          item(Icons.shield_outlined, 'Privacy Policy', () => open(tr('Privacy Policy'), Lang.isUrdu ? _privacyUr : _privacy)),
          item(Icons.description_outlined, 'Terms & Conditions', () => open(tr('Terms & Conditions'), Lang.isUrdu ? _termsUr : _terms)),
          const SizedBox(height: 26),
          Center(
            child: Text(tr('Made with ♥ by Touheed Abbasi'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(tr('© 2026 Senpai Studio. All rights reserved.'),
                style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ],
      ),
    );
  }
}
