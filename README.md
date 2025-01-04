# Awesome Video Downloader

A Flutter plugin for downloading videos in various formats (HLS, DASH, MP4) with support for background downloads, progress tracking, and offline playback.

[![pub package](https://img.shields.io/pub/v/awesome_video_downloader.svg)](https://pub.dev/packages/awesome_video_downloader)
[![likes](https://img.shields.io/pub/likes/awesome_video_downloader)](https://pub.dev/packages/awesome_video_downloader/score)
[![popularity](https://img.shields.io/pub/popularity/awesome_video_downloader)](https://pub.dev/packages/awesome_video_downloader/score)

## Features

- 📥 Multiple format support:
  - HLS (HTTP Live Streaming)
  - DASH (Dynamic Adaptive Streaming over HTTP)
  - MP4 and other direct video files
- 🎥 Quality selection for adaptive streams:
  - Resolution selection (1080p, 720p, etc.)
  - Bitrate control
  - HDR support detection
  - Automatic quality adaptation
- ⚡ Concurrent downloads
- ⏯️ Pause, resume, and cancel downloads
- 📊 Real-time progress tracking
- 🔄 Background download support
- 📱 Cross-platform (iOS & Android)
- 🎥 Offline playback support

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  awesome_video_downloader: ^0.1.3
```

### Platform Setup

#### iOS

Add the following keys to your `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
</array>
```

#### Android

Add these permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

## Usage

### Basic Download

```dart
final downloader = AwesomeVideoDownloader();
await downloader.initialize();

// Start a download
final downloadId = await downloader.startDownload(
  url: 'https://example.com/video.mp4',
  fileName: 'my_video.mp4',
  format: 'mp4',
);

// Monitor progress
downloader.getDownloadProgress(downloadId).listen(
  (progress) {
    print('Progress: ${progress.formattedProgress}');
    print('Speed: ${progress.formattedSpeed}');
    print('Downloaded: ${progress.formattedSize}');
    
    if (progress.isCompleted) {
      print('Download completed! File at: ${progress.filePath}');
    }
  },
  onError: (error) => print('Download error: $error'),
);
```

### Quality Selection

```dart
// Get available qualities
final qualities = await downloader.getAvailableQualities(url);

// Show quality selection dialog
final selectedQuality = await showDialog<VideoQuality>(
  context: context,
  builder: (context) => QualitySelectionDialog(qualities: qualities),
);

if (selectedQuality != null) {
  final downloadId = await downloader.startDownload(
    url: url,
    fileName: 'video.mp4',
    format: 'hls',
    options: VideoDownloadOptions(
      minimumBitrate: selectedQuality.bitrate,
      maximumBitrate: selectedQuality.bitrate,
      preferHDR: selectedQuality.isHDR,
      preferMultichannel: true,
    ),
  );
}
```

### Managing Downloads

```dart
// Pause a download
await downloader.pauseDownload(downloadId);

// Resume a download
await downloader.resumeDownload(downloadId);

// Cancel a download
await downloader.cancelDownload(downloadId);

// Get all downloads
final downloads = await downloader.getAllDownloads();
for (final download in downloads) {
  print('${download.fileName}: ${download.state.name}');
}
```

## Models

### VideoQuality
Quality information for video streams:
```dart
final quality = VideoQuality(
  id: 'quality_id',
  width: 1920,
  height: 1080,
  bitrate: 5000000,  // 5 Mbps
  codec: 'h264',
  isHDR: true,
  label: 'Full HD',
);

print(quality.resolution);    // "1920x1080"
print(quality.bitrateString); // "5.0 Mbps"
print(quality.label);         // "Full HD"
```

### DownloadProgress
Real-time progress information:
```dart
final progress = DownloadProgress(
  id: 'download_123',
  progress: 0.45,          // 45% complete
  bytesDownloaded: 1024,
  totalBytes: 2048,
  speed: 512.0,           // bytes per second
  state: DownloadState.downloading,
  filePath: '/path/to/file.mp4',
);

print(progress.formattedProgress);  // "45.0%"
print(progress.formattedSpeed);     // "0.51 MB/s"
print(progress.formattedSize);      // "1.0/2.0 MB"
```

### VideoDownloadOptions
Configuration for downloads:
```dart
final options = VideoDownloadOptions(
  minimumBitrate: 1500000,    // 1.5 Mbps
  maximumBitrate: 4000000,    // 4 Mbps
  preferHDR: true,
  preferMultichannel: true,
  headers: {
    'Authorization': 'Bearer token123',
  },
);
```

## Error Handling

The plugin provides detailed error information:
```dart
try {
  await downloader.startDownload(
    url: 'invalid_url',
    fileName: 'video.mp4',
    format: 'mp4',
  );
} catch (e) {
  if (e is ArgumentError) {
    print('Invalid arguments: ${e.message}');
  } else {
    print('Download failed: $e');
  }
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.