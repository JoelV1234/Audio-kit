import 'package:flutter/material.dart';

import '../../../models/media_file.dart';

class VideoFileListTile extends StatefulWidget {
  final MediaFile file;
  final VoidCallback? onConvert;
  final VoidCallback? onRemove;
  final VoidCallback? onCancel;

  const VideoFileListTile({
    super.key,
    required this.file,
    this.onConvert,
    this.onRemove,
    this.onCancel,
  });

  @override
  State<VideoFileListTile> createState() => _VideoFileListTileState();
}

class _VideoFileListTileState extends State<VideoFileListTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = widget.file;
    final isProcessing = file.status == MediaFileStatus.processing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Stack(
            children: [
              if (isProcessing)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1.0 + 2.0 * _shimmerController.value,
                              0,
                            ),
                            end: Alignment(
                              -0.5 + 2.0 * _shimmerController.value,
                              0,
                            ),
                            colors: [
                              Colors.transparent,
                              theme.colorScheme.primary.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ListTile(
                enabled: !isProcessing,
                leading: _statusIcon(file.status),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                subtitle:
                    file.status == MediaFileStatus.error
                        ? Text(
                          file.errorMessage ?? 'Unknown error',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                        : Text(
                          file.isRemote
                              ? 'Remote link: ${file.path}'
                              : file.path,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _percentageLabel(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _progressColor(),
                          ),
                        ),
                        if (isProcessing &&
                            file.eta != null &&
                            file.eta!.isNotEmpty)
                          Text(
                            file.eta!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _progressColor(),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    if (widget.onConvert != null) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: widget.onConvert,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Convert'),
                      ),
                    ],
                    if (widget.onCancel != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: widget.onCancel,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                    if (widget.onRemove != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child:
                  isProcessing
                      ? LinearProgressIndicator(
                        value: file.progress > 0 ? file.progress : null,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: Colors.blue,
                      )
                      : LinearProgressIndicator(
                        value: _progressValue(),
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: _progressColor(),
                      ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _percentageLabel() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return '0%';
      case MediaFileStatus.processing:
        return widget.file.progress > 0
            ? '${(widget.file.progress * 100).toStringAsFixed(1)}%'
            : '...';
      case MediaFileStatus.done:
        return '100%';
      case MediaFileStatus.error:
        return 'Error';
    }
  }

  double _progressValue() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return 0.0;
      case MediaFileStatus.processing:
        return widget.file.progress;
      case MediaFileStatus.done:
        return 1.0;
      case MediaFileStatus.error:
        return 1.0;
    }
  }

  Color _progressColor() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return Colors.grey.shade400;
      case MediaFileStatus.processing:
        return Colors.blue;
      case MediaFileStatus.done:
        return Colors.green;
      case MediaFileStatus.error:
        return Colors.red;
    }
  }

  Widget _statusIcon(MediaFileStatus status) {
    switch (status) {
      case MediaFileStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case MediaFileStatus.processing:
        return const Icon(Icons.sync, color: Colors.blue);
      case MediaFileStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MediaFileStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}
