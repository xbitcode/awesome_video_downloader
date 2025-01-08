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
- ⚡ Smart download management:
  - Duplicate detection
  - Concurrent downloads
  - Background processing
- ⏯️ Download controls:
  - Pause/Resume
  - Cancel
  - Progress tracking
- 📱 Cross-platform (iOS & Android)

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  awesome_video_downloader: ^0.1.6
```

### Platform Setup

#### iOS
Add to `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
</array>
```

#### Android
Add to `AndroidManifest.xml`:
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
  },
);

// Check status
final status = await downloader.getDownloadStatus(downloadId);
print('State: ${status.state.name}');
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
    ),
  );
}
```

### Duplicate Handling

```dart
// Will return existing download ID if video is already being downloaded
final downloadId = await downloader.startDownload(
  url: url,
  fileName: 'video.mp4',
  format: 'mp4',
  allowDuplicates: false, // default
);

// Check if video was previously downloaded
final existing = await downloader.checkExistingDownload(url);
if (existing != null) {
  print('Video exists: ${existing.filePath}');
}
```

## Models

### DownloadStatus
Simple status information:
```dart
final status = await downloader.getDownloadStatus(downloadId);
print('State: ${status.state.name}');
print('Error: ${status.error}');
```

### DownloadProgress
Real-time progress information:
```dart
downloader.getDownloadProgress(downloadId).listen((progress) {
  print('Progress: ${progress.formattedProgress}'); // "45.0%"
  print('Speed: ${progress.formattedSpeed}');       // "1.5 MB/s"
});
```

### DownloadInfo
Detailed download information:
```dart
final info = await downloader.getAllDownloads().first;
print('File: ${info.fileName}');
print('URL: ${info.url}');
print('Created: ${info.createdAt}');
print('Size: ${info.formattedSize}');
```

## Error Handling

```dart
try {
  final downloadId = await downloader.startDownload(
    url: 'invalid_url',
    fileName: 'video.mp4',
    format: 'mp4',
  );
} on ArgumentError catch (e) {
  print('Invalid arguments: ${e.message}');
} on StateError catch (e) {
  print('State error: ${e.message}');
} catch (e) {
  print('Download failed: $e');
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


IMPORTANT TO ADD TO INFO PLIST

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>fetch</string>
</array>
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```
