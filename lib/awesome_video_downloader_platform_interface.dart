import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:awesome_video_downloader/models/download_task.dart';
import 'package:awesome_video_downloader/models/download_config.dart';

import 'awesome_video_downloader_method_channel.dart';

abstract class AwesomeVideoDownloaderPlatform extends PlatformInterface {
  AwesomeVideoDownloaderPlatform() : super(token: _token);

  static final Object _token = Object();
  static AwesomeVideoDownloaderPlatform _instance =
      MethodChannelAwesomeVideoDownloader();

  static AwesomeVideoDownloaderPlatform get instance => _instance;

  static set instance(AwesomeVideoDownloaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> startDownload(DownloadConfig config) {
    throw UnimplementedError('startDownload() has not been implemented.');
  }

  Future<void> pauseDownload(String taskId) {
    throw UnimplementedError('pauseDownload() has not been implemented.');
  }

  Future<void> resumeDownload(String taskId) {
    throw UnimplementedError('resumeDownload() has not been implemented.');
  }

  Future<void> cancelDownload(String taskId) {
    throw UnimplementedError('cancelDownload() has not been implemented.');
  }

  Future<List<DownloadTask>> getActiveDownloads() {
    throw UnimplementedError('getActiveDownloads() has not been implemented.');
  }

  Stream<DownloadProgress> getDownloadProgress(String taskId) {
    throw UnimplementedError('getDownloadProgress() has not been implemented.');
  }

  Future<bool> isVideoPlayableOffline(String taskId) {
    throw UnimplementedError(
        'isVideoPlayableOffline() has not been implemented.');
  }

  /// Returns a stream that emits the playable status of the video.
  /// The stream will emit true when the video becomes playable offline
  /// and false when it's not playable.
  Stream<bool> getVideoPlayableStatus(String taskId) {
    throw UnimplementedError(
        'getVideoPlayableStatus() has not been implemented.');
  }

  /// Returns the local file path of the downloaded video.
  /// Returns null if the video hasn't been downloaded or if the file doesn't exist.
  Future<String?> getDownloadedFilePath(String taskId) {
    throw UnimplementedError(
        'getDownloadedFilePath() has not been implemented.');
  }

  /// Deletes the downloaded video file for the given task ID.
  /// Returns true if the file was successfully deleted or didn't exist,
  /// false if the deletion failed.
  Future<bool> deleteDownloadedFile(String taskId) {
    throw UnimplementedError(
        'deleteDownloadedFile() has not been implemented.');
  }
}
