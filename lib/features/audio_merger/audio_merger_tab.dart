import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_format.dart';
import '../../models/media_file.dart';
import '../../services/ffmpeg_merge_service.dart';
import '../../services/linux_file_dialog_service.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/conversion_settings_dialog.dart';
import '../../shared/widgets/drop_hint.dart';
import '../../shared/widgets/ffmpeg_error_dialog.dart';
import '../../shared/widgets/terminal_log_dialog.dart';
import 'widgets/audio_file_list_tile.dart';

part 'logic/audio_merger_tab_inputs.dart';
part 'logic/audio_merger_tab_merge.dart';
part 'logic/audio_merger_tab_view.dart';

const _audioExtensions = {
  '.mp3',
  '.opus',
  '.ogg',
  '.m4a',
  '.aac',
  '.wav',
  '.flac',
  '.wma',
  '.alac',
  '.aiff',
  '.pcm',
  '.webm',
};

class AudioMergerTab extends StatefulWidget {
  final VoidCallback? onStateChanged;

  const AudioMergerTab({super.key, this.onStateChanged});

  @override
  State<AudioMergerTab> createState() => AudioMergerTabState();
}

class AudioMergerTabState extends State<AudioMergerTab>
    with AutomaticKeepAliveClientMixin {
  final List<MediaFile> _files = [];
  AudioFormat _selectedFormat = AudioFormat.mp3;
  String _selectedBitrate = '192k';
  bool _isDragging = false;
  bool _isMerging = false;
  double _mergeProgress = 0.0;
  String _mergeEta = '';
  Process? _activeProcess;
  bool _cancelRequested = false;
  String? _tempPath;
  bool _lastMergeSucceeded = false;

  @override
  bool get wantKeepAlive => true;

  bool get hasUnfinishedWork => _files.isNotEmpty || _isMerging;
  bool get isMerging => _isMerging;
  int get fileCount => _files.length;
  bool get allDone => _lastMergeSucceeded && !_isMerging;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final formatName = prefs.getString('merger_format');
    final bitrate = prefs.getString('merger_bitrate');
    if (formatName != null && mounted) {
      final format = AudioFormat.values.firstWhere(
        (f) => f.name == formatName,
        orElse: () => AudioFormat.mp3,
      );
      setState(() {
        _selectedFormat = format;
        _selectedBitrate = bitrate ?? '192k';
      });
    }
  }

  void _setState(VoidCallback fn) {
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildAudioMergerTab(context);
  }
}
