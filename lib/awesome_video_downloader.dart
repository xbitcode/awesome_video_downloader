// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'models/download_config.dart';
import 'models/download_task.dart';
import 'awesome_video_downloader_platform_interface.dart';

/// A Flutter plugin for downloading videos with support for HLS, DASH, and MP4 formats.
///
/// This plugin handles various authentication scenarios:
/// - Basic authentication using username/password
/// - Token-based authentication
/// - Custom headers
///
/// Example usage with authentication:
/// ```dart
/// final downloader = AwesomeVideoDownloader();
///
/// // Using basic auth
/// final config = DownloadConfig(
///   url: 'https://example.com/video.m3u8',
///   title: 'Protected Video',
///   authentication: {
///     'type': 'basic',
///     'username': 'user',
///     'password': 'pass'
///   }
/// );
///
/// // Using token auth
/// final config = DownloadConfig(
///   url: 'https://example.com/video.m3u8',
///   title: 'Protected Video',
///   authentication: {
///     'type': 'bearer',
///     'token': 'your_access_token'
///   }
/// );
///
/// try {
///   final taskId = await downloader.startDownload(config);
///   downloader.getDownloadProgress(taskId).listen(
///     (progress) {
///       print('Download progress: ${progress.progress}%');
///     },
///     onError: (error) {
///       if (error is AuthenticationRequiredException) {
///         print('This video requires authentication');
///       }
///     }
///   );
/// } catch (e) {
///   print('Download error: $e');
/// }
/// ```
class AwesomeVideoDownloader {
  Future<String?> startDownload(DownloadConfig config) {
    return AwesomeVideoDownloaderPlatform.instance.startDownload(config);
  }

  Future<void> pauseDownload(String taskId) {
    return AwesomeVideoDownloaderPlatform.instance.pauseDownload(taskId);
  }

  Future<void> resumeDownload(String taskId) {
    return AwesomeVideoDownloaderPlatform.instance.resumeDownload(taskId);
  }

  Future<void> cancelDownload(String taskId) {
    return AwesomeVideoDownloaderPlatform.instance.cancelDownload(taskId);
  }

  Future<List<DownloadTask>> getActiveDownloads() {
    return AwesomeVideoDownloaderPlatform.instance.getActiveDownloads();
  }

  Stream<DownloadProgress> getDownloadProgress(String taskId) {
    return AwesomeVideoDownloaderPlatform.instance.getDownloadProgress(taskId);
  }

  Future<bool> isVideoPlayableOffline(String taskId) {
    return AwesomeVideoDownloaderPlatform.instance
        .isVideoPlayableOffline(taskId);
  }
}

/// Exception thrown when a video requires authentication
class AuthenticationRequiredException implements Exception {
  final String message;
  AuthenticationRequiredException(
      [this.message = 'Authentication required for this video']);

  @override
  String toString() => message;
}

/// Exception thrown when authentication fails
class AuthenticationFailedException implements Exception {
  final String message;
  AuthenticationFailedException([this.message = 'Authentication failed']);

  @override
  String toString() => message;
}
