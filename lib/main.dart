import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/audio_kit_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  await windowManager.setTitle('Audio Kit');
  await windowManager.setMinimumSize(const Size(640, 480));
  runApp(const AudioKitApp());
}
