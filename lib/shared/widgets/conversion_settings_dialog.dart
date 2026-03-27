import 'package:flutter/material.dart';

import '../../models/audio_format.dart';

class ConversionSettings {
  final AudioFormat format;
  final String bitrate;
  const ConversionSettings({required this.format, required this.bitrate});
}

const _bitrateOptions = {
  AudioFormat.mp3: ['128k', '192k', '256k', '320k'],
  AudioFormat.opus: ['64k', '96k', '128k', '192k'],
  AudioFormat.heAac: ['32k', '48k', '64k', '96k'],
};

const _defaultBitrates = {
  AudioFormat.mp3: '192k',
  AudioFormat.opus: '128k',
  AudioFormat.heAac: '64k',
};

/// Shows a dialog for the user to pick an output format and bitrate.
/// Returns [ConversionSettings] or null if the user cancelled.
Future<ConversionSettings?> showConversionSettingsDialog(
  BuildContext context, {
  AudioFormat initialFormat = AudioFormat.mp3,
  String? initialBitrate,
  String title = 'Conversion Settings',
  String confirmLabel = 'Convert',
  IconData confirmIcon = Icons.transform,
}) {
  return showDialog<ConversionSettings>(
    context: context,
    builder: (ctx) => _ConversionSettingsDialog(
      initialFormat: initialFormat,
      initialBitrate: initialBitrate,
      title: title,
      confirmLabel: confirmLabel,
      confirmIcon: confirmIcon,
    ),
  );
}

class _ConversionSettingsDialog extends StatefulWidget {
  final AudioFormat initialFormat;
  final String? initialBitrate;
  final String title;
  final String confirmLabel;
  final IconData confirmIcon;

  const _ConversionSettingsDialog({
    this.initialFormat = AudioFormat.mp3,
    this.initialBitrate,
    this.title = 'Conversion Settings',
    this.confirmLabel = 'Convert',
    this.confirmIcon = Icons.transform,
  });

  @override
  State<_ConversionSettingsDialog> createState() =>
      _ConversionSettingsDialogState();
}

class _ConversionSettingsDialogState
    extends State<_ConversionSettingsDialog> {
  late AudioFormat _format = widget.initialFormat;
  late String _bitrate = widget.initialBitrate ?? _defaultBitrates[widget.initialFormat]!;

  void _onFormatChanged(AudioFormat format) {
    setState(() {
      _format = format;
      _bitrate = _defaultBitrates[format]!;
    });
  }

  String _bitrateLabel(String k) => '${k.replaceAll('k', '')} kbps';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bitrates = _bitrateOptions[_format]!;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(widget.title),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Format',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<AudioFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AudioFormat.mp3,
                  label: Text('MP3'),
                  icon: Icon(Icons.audiotrack),
                ),
                ButtonSegment(
                  value: AudioFormat.opus,
                  label: Text('Opus'),
                  icon: Icon(Icons.music_note),
                ),
                ButtonSegment(
                  value: AudioFormat.heAac,
                  label: Text('HE-AAC'),
                  icon: Icon(Icons.surround_sound),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => _onFormatChanged(s.first),
            ),
            const SizedBox(height: 24),
            Text(
              'Bitrate',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments:
                  bitrates
                      .map(
                        (b) => ButtonSegment(
                          value: b,
                          label: Text(_bitrateLabel(b)),
                        ),
                      )
                      .toList(),
              selected: {_bitrate},
              onSelectionChanged:
                  (s) => setState(() => _bitrate = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            ConversionSettings(format: _format, bitrate: _bitrate),
          ),
          icon: Icon(widget.confirmIcon),
          label: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
