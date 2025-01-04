import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'awesome_video_downloader_platform_interface.dart';

/// An implementation of [AwesomeVideoDownloaderPlatform] that uses method channels.
class MethodChannelAwesomeVideoDownloader
    extends AwesomeVideoDownloaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('awesome_video_downloader');
  final eventChannel = const EventChannel('awesome_video_downloader/events');

  @override
  Future<void> initialize() async {
    await methodChannel.invokeMethod<void>('initialize');
  }

  @override
  Future<String> startDownload({
    required String url,
    required String fileName,
    required String format,
    Map<String, dynamic>? options,
  }) async {
    final downloadId =
        await methodChannel.invokeMethod<String>('startDownload', {
      'url': url,
      'fileName': fileName,
      'format': format,
      'options': options,
    });
    return downloadId ?? '';
  }

  @override
  Future<void> pauseDownload(String downloadId) async {
    await methodChannel.invokeMethod<void>('pauseDownload', {
      'downloadId': downloadId,
    });
  }

  @override
  Future<void> resumeDownload(String downloadId) async {
    await methodChannel.invokeMethod<void>('resumeDownload', {
      'downloadId': downloadId,
    });
  }

  @override
  Future<void> cancelDownload(String downloadId) async {
    await methodChannel.invokeMethod<void>('cancelDownload', {
      'downloadId': downloadId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final downloads =
        await methodChannel.invokeMethod<List<Object?>>('getAllDownloads');
    return (downloads ?? [])
        .map((download) => Map<String, dynamic>.from(download as Map))
        .toList();
  }

  @override
  Stream<Map<String, dynamic>> getDownloadProgress(String downloadId) {
    return eventChannel.receiveBroadcastStream({'downloadId': downloadId}).map(
        (event) => Map<String, dynamic>.from(event as Map));
  }

  @override
  Stream<Map<String, dynamic>> getDownloadStatus(String downloadId) {
    final statusChannel = EventChannel(
      'awesome_video_downloader/status/$downloadId',
    );
    return statusChannel.receiveBroadcastStream().map((event) {
      return event as Map<String, dynamic>;
    });
  }
}
