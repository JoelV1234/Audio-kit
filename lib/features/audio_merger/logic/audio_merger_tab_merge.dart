part of '../audio_merger_tab.dart';

extension _AudioMergerTabMerge on AudioMergerTabState {
  Future<void> _cancelMerge() async {
    if (!_isMerging) return;

    final partialFile = _tempPath;

    _setState(() {
      _cancelRequested = true;
      _activeProcess?.kill(ProcessSignal.sigkill);
      _isMerging = false;
      _mergeProgress = 0.0;
      _mergeEta = '';
      _activeProcess = null;
    });
    _notifyParent();

    if (partialFile != null && mounted) {
      final file = File(partialFile);
      if (!await file.exists() || !mounted) return;

      final deleteFile = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              icon: const Icon(
                Icons.delete_outline,
                size: 40,
                color: Colors.orange,
              ),
              title: const Text('Delete Partial File?'),
              content: Text(
                'The merge was cancelled. Would you like to delete '
                'the partially created file?\n\n'
                '${p.basename(partialFile)}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );

      if (deleteFile == true) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 audio files to merge')),
      );
      return;
    }

    final settings = await showConversionSettingsDialog(
      context,
      initialFormat: _selectedFormat,
      initialBitrate: _selectedBitrate,
      title: 'Output Settings',
      confirmLabel: 'Merge',
      confirmIcon: Icons.call_merge,
    );
    if (settings == null) return;

    _selectedFormat = settings.format;
    _selectedBitrate = settings.bitrate;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('merger_format', settings.format.name);
    await prefs.setString('merger_bitrate', settings.bitrate);

    final ext = extensionForFormat(_selectedFormat);
    final outputPath = await LinuxFileDialogService.pickSavePath(
      title: 'Save merged audio as',
      suggestedFileName: 'merged$ext',
    );
    if (outputPath == null) return;

    var finalPath = outputPath;
    if (!finalPath.endsWith(ext)) {
      finalPath = '$finalPath$ext';
    }
    final baseName = p.basenameWithoutExtension(finalPath);
    final dir = p.dirname(finalPath);
    final tempPath = p.join(dir, '$baseName$ext.part');

    _tempPath = tempPath;
    _setState(() {
      _isMerging = true;
      _mergeProgress = 0.0;
      _cancelRequested = false;
      _activeProcess = null;
    });
    _notifyParent();

    try {
      final result = await FfmpegMergeService.mergeAudioFiles(
        inputPaths: _files.map((f) => f.path).toList(),
        outputPath: tempPath,
        format: _selectedFormat,
        bitrate: _selectedBitrate,
        onProcessStarted: (process) {
          if (!mounted) return;
          _setState(() => _activeProcess = process);
        },
        onProgress: (progress, eta) {
          if (!mounted) return;
          _setState(() {
            _mergeProgress = progress;
            _mergeEta = eta;
          });
        },
      );

      if (!mounted) return;

      _setState(() {
        if (result.exitCode == 0) {
          try {
            File(tempPath).renameSync(finalPath);
          } catch (_) {}
          _mergeProgress = 1.0;
        }
        _lastMergeSucceeded = result.exitCode == 0;
      });

      if (mounted && !_cancelRequested) {
        if (result.exitCode == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merged successfully: ${p.basename(finalPath)}'),
              action: SnackBarAction(
                label: 'Show in Folder',
                onPressed:
                    () => NotificationService.revealInFileManager(finalPath),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
          NotificationService.mergeComplete(
            fileName: p.basename(finalPath),
            success: true,
            outputPath: finalPath,
          );
        } else {
          try {
            File(tempPath).deleteSync();
          } catch (_) {}
          showFfmpegErrorDialog(
            context,
            title: 'Merge Failed',
            stderr: result.stderr.toString(),
          );
          NotificationService.mergeComplete(
            fileName: p.basename(finalPath),
            success: false,
          );
        }
      }
    } finally {
      if (!_cancelRequested) {
        try {
          if (File(tempPath).existsSync()) File(tempPath).deleteSync();
        } catch (_) {}
      }
      if (mounted) {
        _setState(() {
          _isMerging = false;
          _activeProcess = null;
        });
        _notifyParent();
      }
    }
  }
}
