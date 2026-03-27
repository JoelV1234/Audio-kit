import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Service for sending Linux desktop notifications via notify-send.
class NotificationService {
  /// Sends a desktop notification. If [outputPath] is provided, the
  /// snackbar in-app will handle opening the folder (see tabs).
  /// The desktop notification always fires as a basic notification.

  static Future<void> revealFile(String filePath) async {
    // 1. Verify the file actually exists first to prevent path errors
    if (!File(filePath).existsSync()) {
      print('File not found at: $filePath');
      return;
    }

    // 2. Try Nautilus (GNOME)
    try {
      var result = await Process.run('nautilus', ['--select', filePath]);
      if (result.exitCode == 0) return;
    } catch (_) {} // Ignored if not installed

    // 3. Try Dolphin (KDE)
    try {
      var result = await Process.run('dolphin', ['--select', filePath]);
      if (result.exitCode == 0) return;
    } catch (_) {}

    // 4. Try Nemo (Cinnamon/Mint)
    try {
      var result = await Process.run('nemo', [filePath]);
      if (result.exitCode == 0) return;
    } catch (_) {}

    // 5. Fallback: Open the parent directory
    try {
      String folderPath = File(filePath).parent.path;
      await Process.run('xdg-open', [folderPath]);
    } catch (e) {
      print('Ultimate fallback failed: $e');
    }
  }

  static Future<void> notify({
    required String title,
    required String body,
    String icon = 'dialog-information',
    String? outputPath,
  }) async {
    try {
      // 1. Start listening to raw system D-Bus events for notification clicks
      var monitor = await Process.start('dbus-monitor', [
        "interface='org.freedesktop.Notifications',member='ActionInvoked'",
      ]);

      monitor.stdout.transform(utf8.decoder).listen((data) {
        // If the event contains our 'open' action key, trigger the folder
        if (data.contains('"open"') && outputPath != null) {
          revealFile(outputPath);
          monitor.kill(); // Stop listening to save memory
        }
      });

      // 2. Send the notification directly using gdbus (which natively supports buttons)
      await Process.run('gdbus', [
        'call', '--session',
        '--dest', 'org.freedesktop.Notifications',
        '--object-path', '/org/freedesktop/Notifications',
        '--method', 'org.freedesktop.Notifications.Notify',
        'AudioKit', '0', icon, title, body,
        "['open', 'Open Folder']", '@a{sv} {}', '5000', // 5000ms timeout
      ]);
    } catch (_) {
      // Best-effort — notify-send may not be installed.
    }
  }

  /// Convenience: notify that a file conversion finished.
  static Future<void> conversionComplete({
    required String fileName,
    required bool success,
    String? outputPath,
  }) {
    return notify(
      title: success ? 'Conversion Complete' : 'Conversion Failed',
      body: fileName,
      icon: success ? 'dialog-information' : 'dialog-error',
      outputPath: success ? outputPath : null,
    );
  }

  /// Convenience: notify that an audio merge finished.
  static Future<void> mergeComplete({
    required String fileName,
    required bool success,
    String? outputPath,
  }) {
    return notify(
      title: success ? 'Merge Complete' : 'Merge Failed',
      body: fileName,
      icon: success ? 'dialog-information' : 'dialog-error',
      outputPath: success ? outputPath : null,
    );
  }

  /// Opens the file manager highlighting the given file.
  /// Can be called from UI buttons (e.g. snackbar "Show in Folder").
  static Future<void> revealInFileManager(String filePath) async {
    // Try FileManager1 D-Bus first (highlights the file).
    final result = await Process.run('gdbus', [
      'call',
      '--session',
      '--dest=org.freedesktop.FileManager1',
      '--object-path=/org/freedesktop/FileManager1',
      '--method=org.freedesktop.FileManager1.ShowItems',
      "['file://$filePath']",
      '',
    ]);
    if (result.exitCode != 0) {
      // Fallback: just open the parent directory.
      await Process.run('xdg-open', [p.dirname(filePath)]);
    }
  }
}
