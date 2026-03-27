import 'dart:io';

import 'package:path/path.dart' as p;

class LinuxFileDialogService {
  static Future<String> downloadsOrHomeDirectory() async {
    final home = Platform.environment['HOME'] ?? '';
    final downloads = p.join(home, 'Downloads');
    if (await Directory(downloads).exists()) {
      return downloads;
    }
    return home;
  }

  static Future<String?> pickDirectory({
    String title = 'Choose output folder',
  }) async {
    final defaultDir = await downloadsOrHomeDirectory();
    final result = await Process.run('zenity', [
      '--file-selection',
      '--directory',
      '--title=$title',
      '--filename=$defaultDir/',
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  static Future<String?> pickSavePath({
    required String title,
    required String suggestedFileName,
  }) async {
    final defaultDir = await downloadsOrHomeDirectory();
    final result = await Process.run('zenity', [
      '--file-selection',
      '--save',
      '--confirm-overwrite',
      '--title=$title',
      '--filename=${p.join(defaultDir, suggestedFileName)}',
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }
}
