part of '../video_to_audio_tab.dart';

extension _VideoToAudioTabConversion on VideoToAudioTabState {
  Future<String?> _pickOutputDir() {
    return LinuxFileDialogService.pickDirectory(title: 'Choose output folder');
  }

  Future<void> _cancelConversion(int index) async {
    final file = _files[index];
    final process = _activeProcesses[file.path];
    if (process == null) return;

    process.kill(ProcessSignal.sigkill);
    _activeProcesses.remove(file.path);
    _skippedInBatch.add(file.path);

    if (mounted) {
      _setState(() {
        _files[index] = _files[index].copyWith(
          status: MediaFileStatus.pending,
          progress: 0.0,
          errorMessage: null,
        );
        _isConverting = _activeProcesses.isNotEmpty;
      });
      _notifyParent();
    }
  }

  Future<void> _cancelAllConversions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel All?'),
            content: const Text(
              'Are you sure you want to cancel all current and pending conversions?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Cancel All'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      _cancelRequested = true;
      if (mounted) {
        _setState(() {
          for (final entry in _activeProcesses.entries) {
            final path = entry.key;
            final idx = _files.indexWhere((f) => f.path == path);
            if (idx != -1) {
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.pending,
                progress: 0.0,
                errorMessage: null,
              );
            }
            entry.value.kill(ProcessSignal.sigkill);
          }
          _activeProcesses.clear();
          _isConverting = false;
        });
        _notifyParent();
      }
    }
  }

  Future<void> _convertSingle(int index) async {
    final file = _files[index];
    if (file.status != MediaFileStatus.pending) return;

    // 1. Ask user for format + bitrate.
    final settings = await showConversionSettingsDialog(context);
    if (settings == null || !mounted) return;

    // 2. Ask user where to save.
    final outputDir = await _pickOutputDir();
    if (outputDir == null || !mounted) return;

    _setState(() {
      _isConverting = true;
      _files[index] = file.copyWith(
        status: MediaFileStatus.processing,
        progress: 0.0,
      );
    });
    _notifyParent();

    final baseName = p.basenameWithoutExtension(file.path);
    final ext = extensionForFormat(settings.format);
    final outputPath = p.join(outputDir, '$baseName$ext');
    final tempPath = p.join(outputDir, '$baseName$ext.part');
    final filePath = file.path;

    try {
      final result = await FfmpegConversionService.convertVideoToAudio(
        inputPath: file.path,
        outputPath: tempPath,
        format: settings.format,
        bitrate: settings.bitrate,
        onProcessStarted: (process) {
          if (!mounted) return;
          _setState(() => _activeProcesses[filePath] = process);
        },
        onProgress: (progress, eta) {
          if (!mounted) return;
          _setState(() {
            final idx = _files.indexWhere((f) => f.path == filePath);
            if (idx != -1) {
              _files[idx] = _files[idx].copyWith(progress: progress, eta: eta);
            }
          });
          _notifyParent();
        },
      );

      if (!mounted) return;

      String? errorToShow;
      String? errorFileName;
      _setState(() {
        _activeProcesses.remove(filePath);
        final idx = _files.indexWhere((f) => f.path == filePath);
        if (idx != -1 && _files[idx].status == MediaFileStatus.processing) {
          if (result.exitCode == 0) {
            try {
              File(tempPath).renameSync(outputPath);
            } catch (_) {}
            _files[idx] = _files[idx].copyWith(
              status: MediaFileStatus.done,
              progress: 1.0,
              outputPath: outputPath,
            );
            NotificationService.conversionComplete(
              fileName: _files[idx].name,
              success: true,
              outputPath: outputPath,
            );
          } else {
            try {
              File(tempPath).deleteSync();
            } catch (_) {}
            _files[idx] = _files[idx].copyWith(
              status: MediaFileStatus.error,
              errorMessage: result.stderr.toString(),
            );
            NotificationService.conversionComplete(
              fileName: _files[idx].name,
              success: false,
            );
            errorToShow = result.stderr.toString();
            errorFileName = _files[idx].name;
          }
        }
      });
      if (mounted && errorToShow != null) {
        showFfmpegErrorDialog(
          context,
          title: 'Conversion Failed',
          fileName: errorFileName,
          stderr: errorToShow!,
        );
      }
    } finally {
      try {
        if (File(tempPath).existsSync()) File(tempPath).deleteSync();
      } catch (_) {}
      if (mounted) {
        _setState(() {
          _activeProcesses.remove(filePath);
          _isConverting = _activeProcesses.isNotEmpty;
        });
        _notifyParent();
      }
    }
  }

  Future<void> _convertAll() async {
    if (_files.isEmpty || _isConverting) return;

    final hasPending = _files.any((f) => f.status == MediaFileStatus.pending);
    if (!hasPending) return;

    // 1. Ask user for format + bitrate.
    final settings = await showConversionSettingsDialog(context);
    if (settings == null || !mounted) return;

    // 2. Ask user where to save.
    final outputDir = await _pickOutputDir();
    if (outputDir == null || !mounted) return;

    _setState(() {
      _isConverting = true;
      _cancelRequested = false;
      _skippedInBatch.clear();
      _conversionStartTime = DateTime.now();
      _filesCompletedSoFar = 0;
    });
    _notifyParent();

    try {
      while (true) {
        if (!mounted || _cancelRequested) break;

        final i = _files.indexWhere(
          (f) => f.status == MediaFileStatus.pending && !_skippedInBatch.contains(f.path),
        );
        if (i == -1) break;

        final file = _files[i];
        _setState(() {
          _files[i] = file.copyWith(
            status: MediaFileStatus.processing,
            progress: 0.0,
          );
        });
        _notifyParent();

        final baseName = p.basenameWithoutExtension(file.path);
        final ext = extensionForFormat(settings.format);
        final outputPath = p.join(outputDir, '$baseName$ext');
        final tempPath = p.join(outputDir, '$baseName$ext.part');
        final filePath = file.path;

        final result = await FfmpegConversionService.convertVideoToAudio(
          inputPath: file.path,
          outputPath: tempPath,
          format: settings.format,
          bitrate: settings.bitrate,
          onProcessStarted: (process) {
            if (!mounted) return;
            _setState(() => _activeProcesses[filePath] = process);
          },
          onProgress: (progress, eta) {
            if (!mounted) return;
            _setState(() {
              final idx = _files.indexWhere((f) => f.path == filePath);
              if (idx != -1) {
                _files[idx] = _files[idx].copyWith(
                  progress: progress,
                  eta: eta,
                );
              }
            });
            _notifyParent();
          },
        );

        if (!mounted) return;
        if (_cancelRequested) {
          try {
            File(tempPath).deleteSync();
          } catch (_) {}
          break;
        }

        _filesCompletedSoFar++;

        String? errorToShow;
        String? errorFileName;
        _setState(() {
          _activeProcesses.remove(filePath);
          final idx = _files.indexWhere((f) => f.path == filePath);
          if (idx != -1 && _files[idx].status == MediaFileStatus.processing) {
            if (result.exitCode == 0) {
              try {
                File(tempPath).renameSync(outputPath);
              } catch (_) {}
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.done,
                progress: 1.0,
                outputPath: outputPath,
              );
              NotificationService.conversionComplete(
                fileName: _files[idx].name,
                success: true,
                outputPath: outputPath,
              );
            } else {
              try {
                File(tempPath).deleteSync();
              } catch (_) {}
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.error,
                errorMessage: result.stderr.toString(),
              );
              NotificationService.conversionComplete(
                fileName: _files[idx].name,
                success: false,
              );
              errorToShow = result.stderr.toString();
              errorFileName = _files[idx].name;
            }
          }
        });
        // Delete temp file if individually cancelled (status reverted to pending)
        if (result.exitCode != 0) {
          try {
            if (File(tempPath).existsSync()) File(tempPath).deleteSync();
          } catch (_) {}
        }
        if (mounted && errorToShow != null) {
          showFfmpegErrorDialog(
            context,
            title: 'Conversion Failed',
            fileName: errorFileName,
            stderr: errorToShow!,
          );
        }
        _notifyParent();
      }
    } finally {
      if (mounted) {
        _setState(() => _isConverting = false);
        _notifyParent();
      }
    }

    if (mounted && !_cancelRequested) {
      final doneCount =
          _files.where((f) => f.status == MediaFileStatus.done).length;
      final errorCount =
          _files.where((f) => f.status == MediaFileStatus.error).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conversion complete: $doneCount done, $errorCount errors',
          ),
          action: SnackBarAction(
            label: 'Show in Folder',
            onPressed: () {
              final lastDone = _files.lastWhere(
                (f) => f.status == MediaFileStatus.done,
                orElse: () => _files.first,
              );
              final revealedPath = lastDone.outputPath ?? lastDone.path;
              NotificationService.revealInFileManager(revealedPath);
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }
}
