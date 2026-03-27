part of '../audio_merger_tab.dart';

extension _AudioMergerTabInputs on AudioMergerTabState {
  void _notifyParent() {
    widget.onStateChanged?.call();
  }

  int _addFiles(List<String> paths) {
    var skipped = 0;
    _setState(() {
      for (final path in paths) {
        final ext = p.extension(path).toLowerCase();
        if (_audioExtensions.contains(ext)) {
          if (!_files.any((f) => f.path == path)) {
            _files.add(MediaFile(path: path, name: p.basename(path)));
          }
        } else {
          skipped++;
        }
      }
      _files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    _notifyParent();
    return skipped;
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
              '$skipped non-audio file${skipped == 1 ? '' : 's'} skipped.',
            ),
            backgroundColor: Colors.orange.shade700,
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

      final audioCount =
          allFolderFiles
              .where(
                (f) => _audioExtensions.contains(p.extension(f).toLowerCase()),
              )
              .length;

      if (audioCount == 0) {
        await showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                icon: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Colors.orange,
                ),
                title: const Text('No Audio Files Found'),
                content: const Text(
                  'There are no supported audio files in the dropped folder(s).',
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
                audioCount == allFolderFiles.length
                    ? 'Import $audioCount audio file${audioCount == 1 ? '' : 's'}'
                    : 'Found ${allFolderFiles.length} item${allFolderFiles.length == 1 ? '' : 's'} '
                        'in ${folderPaths.length == 1 ? 'this folder' : '${folderPaths.length} folders'}.\n\n'
                        'Only $audioCount of them ${audioCount == 1 ? 'is an audio file' : 'are audio files'}.\n\n'
                        'Would you like to import the audio files',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'import'),
                  icon: const Icon(Icons.audiotrack),
                  label: const Text('Import Audio Files'),
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
      allowedExtensions: _audioExtensions.map((e) => e.substring(1)).toList(),
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
      _files.clear();
      _lastMergeSucceeded = false;
    });
    _notifyParent();
  }

  void _onReorder(int oldIndex, int newIndex) {
    _setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
    });
  }
}
