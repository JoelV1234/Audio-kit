import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import 'audio_kit_home.dart';

class AudioKitApp extends StatefulWidget {
  const AudioKitApp({super.key});

  @override
  State<AudioKitApp> createState() => _AudioKitAppState();
}

class _AudioKitAppState extends State<AudioKitApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioKit',
      debugShowCheckedModeBanner: false,
      theme: yaruLight,
      darkTheme: yaruDark,
      themeMode: _themeMode,
      home: AudioKitHome(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
