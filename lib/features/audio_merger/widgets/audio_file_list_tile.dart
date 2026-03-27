import 'package:flutter/material.dart';

import '../../../models/media_file.dart';

/// A reorderable list tile representing one audio file in the merger queue.
class AudioFileListTile extends StatelessWidget {
  final MediaFile file;
  final int index;
  final bool isMerging;
  final VoidCallback? onRemove;

  const AudioFileListTile({
    super.key,
    required this.file,
    required this.index,
    required this.isMerging,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading:
          isMerging
              ? const Icon(Icons.drag_handle, color: Colors.grey)
              : ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        file.path,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing:
          isMerging
              ? null
              : IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
    );
  }
}
