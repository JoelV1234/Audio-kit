# AudioKit

A free and open-source desktop app for Linux to convert video files to audio and merge audio files, powered by ffmpeg and built with Flutter.

## Features

### Video to Audio
- Convert MP4, MKV, AVI, MOV, WEBM, FLV and other video formats to audio
- Output formats: MP3, Opus, HE-AAC
- Choose bitrate per conversion
- Add files via drag & drop, file picker, or direct media URLs
- Per-file or batch conversion
- Cancel individual files or all conversions
- Real-time progress and ETA per file

### Audio Merger
- Merge multiple audio files into a single output file
- Supports MP3, Opus, OGG, M4A, AAC, WAV, FLAC, WMA, ALAC, AIFF, and more
- Files are automatically sorted alphabetically when added
- Drag to reorder before merging
- Output formats: MP3, Opus, HE-AAC
- Cancel mid-merge with option to keep or delete the partial file
- Live process log viewer

## Requirements

- Linux (x86_64)
- [ffmpeg](https://ffmpeg.org/) must be installed and on your `PATH`

```bash
# Ubuntu / Debian
sudo apt install ffmpeg

# Fedora
sudo dnf install ffmpeg

# Arch
sudo pacman -S ffmpeg
```

## Installation

Download the latest `.deb` from the [Releases](../../releases) page and install:

```bash
sudo dpkg -i audiokit-1.0.0+1-linux.deb
```

Or double-click the `.deb` file in your file manager.

## Building from Source

Requires [Flutter](https://flutter.dev) 3.29 or later.

```bash
git clone https://github.com/JoelV1234/audiokit.git
cd audiokit
flutter pub get
flutter build linux --release
```

The built binary will be at `build/linux/x64/release/bundle/audiokit`.

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright (c) 2026 Joel Vaz
