# Solo Player: Your Media. Your Way.

A lightweight, offline media player for Android built with Flutter. Play your local music and videos with a clean, minimal interface, with no ads and no internet needed.

## Download
📥 Latest APK: see the **Releases** section of this repo
(Android 9+ par test kiya gaya hai)

## Features
- Plays local audio (MP3) and video (MP4, MKV) files from device storage
- Play, pause and seek controls
- Android runtime storage permission handling
- Minimal UI with light and dark theme
- Automatic Release APK build using GitHub Actions

## Planned / In progress
- Auto file scan and folder-wise video series view
- Music notification with controls
- Library (songs, artists, albums, playlists)
- Settings with theme and language (English / Urdu)

## Tech Stack
Flutter, Dart, media_kit, GitHub Actions (CI/CD)

## Screenshots
![Home](screenshots/home.png)
![Now playing](screenshots/player.png)

## Build locally
```bash
git clone https://github.com/TouheedAbbasi/solo-player.git
cd solo-player
flutter pub get
flutter run
# Release APK:
flutter build apk --release
```

## Author
Touheed Abbasi, Junior Web & App Developer, Karachi
