part of '../audio_merger_tab.dart';

extension _AudioMergerTabView on AudioMergerTabState {
  Widget _buildAudioMergerTab(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
        _onDropDone(details);
      },
      onDragEntered: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
        _setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 1) return;
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
                  Icon(Icons.merge_type, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Audio Merger', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isMerging ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                  ),
                  const SizedBox(width: 12),
                  if (!_isMerging)
                    ElevatedButton.icon(
                      onPressed: _files.length < 2 ? null : _merge,
                      icon: const Icon(Icons.call_merge),
                      label: const Text('Merge'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _cancelMerge,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed:
                        (_isMerging || _files.isEmpty) ? null : _clearFiles,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.terminal),
                    tooltip: 'Show process log',
                    onPressed: () => showTerminalLogDialog(context),
                  ),
                  const SizedBox(width: 4),
                  const Text('Output: '),
                  const SizedBox(width: 8),
                  DropdownButton<AudioFormat>(
                    value: _selectedFormat,
                    onChanged:
                        _isMerging
                            ? null
                            : (v) => _setState(() => _selectedFormat = v!),
                    items:
                        AudioFormat.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(labelForFormat(f)),
                              ),
                            )
                            .toList(),
                  ),
                  if (_files.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${_files.length} files - drag to reorder',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (_isMerging)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _mergeProgress > 0 ? _mergeProgress : null,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _mergeProgress > 0
                              ? 'Merging ${_files.length} files... ${(_mergeProgress * 100).toStringAsFixed(1)}%'
                              : 'Preparing files for merge...',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_mergeEta.isNotEmpty)
                          Text(
                            _mergeEta,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    _files.isEmpty
                        ? const DropHint(
                          primaryText:
                              'Drag & drop audio files or folders here\nor use "Add Files" button',
                          formatsText:
                              'Supports: MP3, Opus, OGG, M4A, AAC, WAV, FLAC, and more',
                        )
                        : ReorderableListView.builder(
                          itemCount: _files.length,
                          onReorder: _isMerging ? (_, __) {} : _onReorder,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return AudioFileListTile(
                              key: ValueKey(file.path),
                              file: file,
                              index: index,
                              isMerging: _isMerging,
                              onRemove: () => _removeFile(index),
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
