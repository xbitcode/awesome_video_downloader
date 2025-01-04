import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'awesome_video_downloader_method_channel.dart';

abstract class AwesomeVideoDownloaderPlatform extends PlatformInterface {
  /// Constructs a AwesomeVideoDownloaderPlatform.
  AwesomeVideoDownloaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static AwesomeVideoDownloaderPlatform _instance =
      MethodChannelAwesomeVideoDownloader();

  /// The default instance of [AwesomeVideoDownloaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelAwesomeVideoDownloader].
  static AwesomeVideoDownloaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AwesomeVideoDownloaderPlatform] when
  /// they register themselves.
  static set instance(AwesomeVideoDownloaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<String> startDownload({
    required String url,
    required String fileName,
    required String format,
    Map<String, dynamic>? options,
  }) {
    throw UnimplementedError('startDownload() has not been implemented.');
  }

  Future<void> pauseDownload(String downloadId) {
    throw UnimplementedError('pauseDownload() has not been implemented.');
  }

  Future<void> resumeDownload(String downloadId) {
    throw UnimplementedError('resumeDownload() has not been implemented.');
  }

  Future<void> cancelDownload(String downloadId) {
    throw UnimplementedError('cancelDownload() has not been implemented.');
  }

  Future<Map<String, dynamic>> getDownloadStatus(String downloadId) {
    throw UnimplementedError('getDownloadStatus() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getAllDownloads() {
    throw UnimplementedError('getAllDownloads() has not been implemented.');
  }

  Stream<Map<String, dynamic>> getDownloadProgress(String downloadId) {
    throw UnimplementedError('getDownloadProgress() has not been implemented.');
  }
}
