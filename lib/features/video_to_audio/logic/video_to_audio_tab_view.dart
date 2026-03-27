part of '../video_to_audio_tab.dart';

extension _VideoToAudioTabView on VideoToAudioTabState {
  Widget _buildVideoToAudioTab(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        _onDropDone(details);
      },
      onDragEntered: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        _setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        _setState(() => _isDragging = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border:
              _isDragging
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.video_file, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Video to Audio', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isConverting ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _linkController,
                      enabled: !_isConverting,
                      onSubmitted: (_) => _addLinksFromInput(),
                      decoration: const InputDecoration(
                        labelText: 'Video link',
                        hintText: 'Paste one or more direct media URLs',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isConverting ? null : _addLinksFromInput,
                    icon: const Icon(Icons.link),
                    label: const Text('Add Link'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed:
                        _isConverting
                            ? _cancelAllConversions
                            : (pendingCount == 0 ? null : _convertAll),
                    icon: Icon(_isConverting ? Icons.cancel : Icons.transform),
                    label: Text(_isConverting ? 'Cancel All' : 'Convert All'),
                    style:
                        _isConverting
                            ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.red,
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _files.isEmpty ? null : _clearFiles,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _files.isEmpty
                        ? const DropHint(
                          primaryText:
                              'Drag video files or folders here,\nuse "Add Files", or paste direct video links',
                          formatsText:
                              'Supported dropped files: MP4, MKV, AVI, MOV, WEBM, FLV',
                        )
                        : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return VideoFileListTile(
                              file: file,
                              onConvert:
                                  file.status == MediaFileStatus.pending
                                      ? () => _convertSingle(index)
                                      : null,
                              onCancel:
                                  file.status == MediaFileStatus.processing
                                      ? () => _cancelConversion(index)
                                      : null,
                              onRemove:
                                  _isConverting &&
                                          file.status ==
                                              MediaFileStatus.processing
                                      ? null
                                      : () => _removeFile(index),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
