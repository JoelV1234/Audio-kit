import 'package:flutter/material.dart';

import '../../features/audio_merger/audio_merger_tab.dart';
import '../../features/video_to_audio/video_to_audio_tab.dart';
import 'progress_row.dart';
import 'status_card.dart';

Future<bool> showCloseConfirmationDialog({
  required BuildContext context,
  required VideoToAudioTabState? videoState,
  required AudioMergerTabState? mergerState,
}) async {
  final videoHasWork = videoState?.hasUnfinishedWork ?? false;
  final mergerHasWork = mergerState?.hasUnfinishedWork ?? false;
  final videoConverting = videoState?.isConverting ?? false;
  final mergerMerging = mergerState?.isMerging ?? false;

  if (!videoHasWork && !mergerHasWork) return true;

  final isProcessing = videoConverting || mergerMerging;

  final shouldClose = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isProcessing
                            ? [
                              Colors.orange.shade700,
                              Colors.deepOrange.shade500,
                            ]
                            : [Colors.blue.shade600, Colors.indigo.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isProcessing
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isProcessing ? 'Work in Progress' : 'Unprocessed Files',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isProcessing
                          ? 'Closing now will cancel active operations'
                          : 'You have files waiting to be processed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: [
                    if (videoConverting)
                      StatusCard(
                        icon: Icons.video_file,
                        iconGradient: [
                          Colors.blue.shade400,
                          Colors.blue.shade700,
                        ],
                        title: 'Video to Audio',
                        statusLabel: 'CONVERTING',
                        statusColor: Colors.blue,
                        isDark: isDark,
                        child: Column(
                          children: [
                            ProgressRow(
                              label:
                                  '${(videoState!.overallProgress * 100).toStringAsFixed(0)}%',
                              progress: videoState.overallProgress,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  videoState.estimatedTimeRemaining,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${videoState.processingCount} processing · ${videoState.pendingCount} queued',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else if (videoHasWork)
                      StatusCard(
                        icon: Icons.video_file,
                        iconGradient: [
                          Colors.orange.shade400,
                          Colors.orange.shade700,
                        ],
                        title: 'Video to Audio',
                        statusLabel: 'PENDING',
                        statusColor: Colors.orange,
                        isDark: isDark,
                        child: Text(
                          '${videoState!.pendingCount} file${videoState.pendingCount != 1 ? 's' : ''} added but not yet converted',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    if ((videoHasWork || videoConverting) &&
                        (mergerHasWork || mergerMerging))
                      const SizedBox(height: 12),
                    if (mergerMerging)
                      StatusCard(
                        icon: Icons.merge_type,
                        iconGradient: [
                          Colors.blue.shade400,
                          Colors.blue.shade700,
                        ],
                        title: 'Audio Merger',
                        statusLabel: 'MERGING',
                        statusColor: Colors.blue,
                        isDark: isDark,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: const LinearProgressIndicator(
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Merge in progress...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (mergerHasWork)
                      StatusCard(
                        icon: Icons.merge_type,
                        iconGradient: [
                          Colors.orange.shade400,
                          Colors.orange.shade700,
                        ],
                        title: 'Audio Merger',
                        statusLabel: 'PENDING',
                        statusColor: Colors.orange,
                        isDark: isDark,
                        child: Text(
                          '${mergerState!.fileCount} file${mergerState.fileCount != 1 ? 's' : ''} added but not yet merged',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Go Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Close App'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  return shouldClose ?? false;
}
