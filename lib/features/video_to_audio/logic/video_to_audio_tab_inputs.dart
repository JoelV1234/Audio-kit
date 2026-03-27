part of '../video_to_audio_tab.dart';

extension _VideoToAudioTabInputs on VideoToAudioTabState {
  void _notifyParent() {
    widget.onStateChanged?.call();
  }

  int _addFiles(List<String> paths) {
    var skipped = 0;
    _setState(() {
      for (final path in paths) {
        final ext = p.extension(path).toLowerCase();
        if (_videoExtensions.contains(ext)) {
          if (!_files.any((f) => f.path == path)) {
            _files.add(MediaFile(path: path, name: p.basename(path)));
          }
        } else {
          skipped++;
        }
      }
    });
    _notifyParent();
    return skipped;
  }

  int _addLinks(List<String> rawLinks) {
    var added = 0;
    _setState(() {
      for (final rawLink in rawLinks) {
        final link = rawLink.trim();
        if (!_isSupportedVideoUrl(link)) continue;
        if (_files.any((f) => f.path == link)) continue;
        _files.add(
          MediaFile(path: link, name: _displayNameForUrl(link), isRemote: true),
        );
        added++;
      }
    });
    _notifyParent();
    return added;
  }

  bool _isSupportedVideoUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }

    final extension = p.extension(uri.path).toLowerCase();
    if (extension.isEmpty) return true;
    return _videoExtensions.contains(extension);
  }

  String _displayNameForUrl(String url) {
    final uri = Uri.tryParse(url);
    final segment =
        uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    if (segment.isNotEmpty) {
      return Uri.decodeComponent(segment);
    }
    return uri?.host ?? url;
  }

  void _addLinksFromInput() {
    final entries =
        _linkController.text
            .split(RegExp(r'[\n\r\s]+'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

    if (entries.isEmpty) return;

    final added = _addLinks(entries);
    _linkController.clear();

    if (added == 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Paste one or more direct http/https video links to add them.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<List<String>> _collectFilesFromDir(String dirPath) async {
    final dir = Directory(dirPath);
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
    return files;
  }

  Future<void> _onDropDone(DropDoneDetails details) async {
    final directFiles = <String>[];
    final folderPaths = <String>[];

    for (final xfile in details.files) {
      final path = xfile.path;
      if (await FileSystemEntity.isDirectory(path)) {
        folderPaths.add(path);
      } else {
        directFiles.add(path);
      }
    }

    if (directFiles.isNotEmpty) {
      final skipped = _addFiles(directFiles);
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$skipped non-video file${skipped > 1 ? 's were' : ' was'} skipped. '
              'Only video files (mp4, mkv, avi, mov, webm, flv) are accepted.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    if (folderPaths.isNotEmpty && mounted) {
      final allFolderFiles = <String>[];
      for (final dir in folderPaths) {
        allFolderFiles.addAll(await _collectFilesFromDir(dir));
      }
      if (!mounted) return;

      final videoCount =
          allFolderFiles
              .where(
                (f) => _videoExtensions.contains(p.extension(f).toLowerCase()),
              )
              .length;

      if (videoCount == 0) {
        await showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                icon: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Colors.orange,
                ),
                title: const Text('No Video Files Found'),
                content: const Text(
                  'There are no supported video files in the dropped folder(s).',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
        return;
      }

      final action = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              icon: const Icon(Icons.folder_open, size: 40),
              title: const Text('Import Folder'),
              content: Text(
                videoCount == allFolderFiles.length
                    ? 'Import $videoCount video file${videoCount == 1 ? '' : 's'}'
                    : 'Found ${allFolderFiles.length} item${allFolderFiles.length == 1 ? '' : 's'} '
                        'in ${folderPaths.length == 1 ? 'this folder' : '${folderPaths.length} folders'}.\n\n'
                        'Only $videoCount of them ${videoCount == 1 ? 'is a video file' : 'are video files'}.\n\n'
                        'Would you like to import the video files',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'import'),
                  icon: const Icon(Icons.video_file),
                  label: const Text('Import Video Files'),
                ),
              ],
            ),
      );

      if (!mounted) return;
      if (action == 'import') {
        _addFiles(allFolderFiles);
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'],
      allowMultiple: true,
    );
    if (result != null) {
      _addFiles(result.paths.whereType<String>().toList());
    }
  }

  void _removeFile(int index) {
    _setState(() {
      _files.removeAt(index);
    });
    _notifyParent();
  }

  void _clearFiles() {
    _setState(() {
      if (_isConverting) {
        _files.removeWhere((f) => f.status != MediaFileStatus.processing);
      } else {
        _files.clear();
      }
    });
    _notifyParent();
  }
}
