import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/audio_format.dart';
import '../../models/media_file.dart';
import '../../services/ffmpeg_conversion_service.dart';
import '../../services/linux_file_dialog_service.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/conversion_settings_dialog.dart';
import '../../shared/widgets/drop_hint.dart';
import '../../shared/widgets/ffmpeg_error_dialog.dart';
import 'widgets/video_file_list_tile.dart';

part 'logic/video_to_audio_tab_inputs.dart';
part 'logic/video_to_audio_tab_conversion.dart';
part 'logic/video_to_audio_tab_view.dart';

const _videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv'};

class VideoToAudioTab extends StatefulWidget {
  final VoidCallback? onStateChanged;

  const VideoToAudioTab({super.key, this.onStateChanged});

  @override
  State<VideoToAudioTab> createState() => VideoToAudioTabState();
}

class VideoToAudioTabState extends State<VideoToAudioTab>
    with AutomaticKeepAliveClientMixin {
  final List<MediaFile> _files = [];
  final TextEditingController _linkController = TextEditingController();
  bool _isDragging = false;
  bool _isConverting = false;
  DateTime? _conversionStartTime;
  int _filesCompletedSoFar = 0;
  final Map<String, Process> _activeProcesses = {};
  bool _cancelRequested = false;
  final Set<String> _skippedInBatch = {};

  @override
  bool get wantKeepAlive => true;

  bool get hasUnfinishedWork {
    return _files.any(
      (f) =>
          f.status == MediaFileStatus.pending ||
          f.status == MediaFileStatus.processing,
    );
  }

  bool get isConverting => _isConverting;

  bool get allDone {
    if (_files.isEmpty) return false;
    return _files.every(
      (f) =>
          f.status == MediaFileStatus.done || f.status == MediaFileStatus.error,
    );
  }

  int get pendingCount =>
      _files.where((f) => f.status == MediaFileStatus.pending).length;

  double get overallProgress {
    if (_files.isEmpty) return 0;
    final done =
        _files
            .where(
              (f) =>
                  f.status == MediaFileStatus.done ||
                  f.status == MediaFileStatus.error,
            )
            .length;
    return done / _files.length;
  }

  String get estimatedTimeRemaining {
    if (_conversionStartTime == null || _filesCompletedSoFar == 0) {
      return 'Calculating...';
    }
    final elapsed = DateTime.now().difference(_conversionStartTime!);
    final avgPerFile = elapsed.inSeconds / _filesCompletedSoFar;
    final remaining =
        _files
            .where(
              (f) =>
                  f.status == MediaFileStatus.pending ||
                  f.status == MediaFileStatus.processing,
            )
            .length;
    final secsLeft = (avgPerFile * remaining).round();
    if (secsLeft < 60) return '~${secsLeft}s remaining';
    final mins = secsLeft ~/ 60;
    final secs = secsLeft % 60;
    return '~${mins}m ${secs}s remaining';
  }

  int get processingCount =>
      _files.where((f) => f.status == MediaFileStatus.processing).length;

  void _setState(VoidCallback fn) {
    setState(fn);
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildVideoToAudioTab(context);
  }
}
