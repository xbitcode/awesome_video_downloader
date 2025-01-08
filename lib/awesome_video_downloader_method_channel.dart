import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:awesome_video_downloader/models/download_task.dart';
import 'package:awesome_video_downloader/models/download_config.dart';
import 'awesome_video_downloader_platform_interface.dart';

/// An implementation of [AwesomeVideoDownloaderPlatform] that uses method channels.
class MethodChannelAwesomeVideoDownloader
    extends AwesomeVideoDownloaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('awesome_video_downloader');

  // Create separate event channels for each task
  final _eventChannels = <String, EventChannel>{};
  final _progressStreams = <String, Stream<DownloadProgress>>{};
  final _playableStatusStreams = <String, Stream<bool>>{};

  @override
  Future<String?> startDownload(DownloadConfig config) async {
    try {
      final taskId = await methodChannel.invokeMethod<String>(
        'startDownload',
        config.toMap(),
      );
      return taskId;
    } catch (e) {
      print('#### Flutter: Error starting download: $e');
      rethrow;
    }
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'pauseDownload',
      {'taskId': taskId},
    );
    return;
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'resumeDownload',
      {'taskId': taskId},
    );
    return;
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'cancelDownload',
      {'taskId': taskId},
    );
    _eventChannels.remove(taskId);
    _eventChannels.remove('playable_$taskId');
    _progressStreams.remove(taskId);
    _playableStatusStreams.remove(taskId);
    return;
  }

  @override
  Stream<DownloadProgress> getDownloadProgress(String taskId) {
    // Use existing iOS implementation
    if (_progressStreams.containsKey(taskId)) {
      return _progressStreams[taskId]!;
    }

    final eventChannel =
        EventChannel('awesome_video_downloader/events/$taskId');
    _eventChannels[taskId] = eventChannel;

    final stream =
        eventChannel.receiveBroadcastStream({'taskId': taskId}).map((event) {
      if (event == null) {
        return DownloadProgress(
          taskId: taskId,
          progress: 0.0,
          bytesDownloaded: 0,
          totalBytes: 0,
          isCancelled: true,
        );
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(event as Map);
      return DownloadProgress(
        taskId: taskId,
        progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
        bytesDownloaded: (data['bytesDownloaded'] as num?)?.toInt() ?? 0,
        totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
        isCancelled: false,
      );
    }).asBroadcastStream();

    _progressStreams[taskId] = stream;
    return stream;
  }

  @override
  Future<bool> isVideoPlayableOffline(String taskId) async {
    return await methodChannel.invokeMethod(
      'isVideoPlayableOffline',
      {'taskId': taskId},
    );
  }

  @override
  Future<String?> getDownloadedFilePath(String taskId) async {
    return await methodChannel.invokeMethod(
      'getDownloadedFilePath',
      {'taskId': taskId},
    );
  }

  @override
  Future<bool> deleteDownloadedFile(String taskId) async {
    return await methodChannel.invokeMethod(
      'deleteDownloadedFile',
      {'taskId': taskId},
    );
  }

  @override
  Stream<bool> getVideoPlayableStatus(String taskId) {
    if (_playableStatusStreams.containsKey(taskId)) {
      return _playableStatusStreams[taskId]!;
    }

    final eventChannel =
        EventChannel('awesome_video_downloader/playable_status/$taskId');
    _eventChannels['playable_$taskId'] = eventChannel;

    final stream =
        eventChannel.receiveBroadcastStream({'taskId': taskId}).map((event) {
      if (event == null) return false;
      final Map<String, dynamic> data = Map<String, dynamic>.from(event as Map);
      return data['isPlayable'] as bool? ?? false;
    }).asBroadcastStream();

    _playableStatusStreams[taskId] = stream;
    return stream;
  }

  @override
  Future<List<DownloadTask>> getActiveDownloads() async {
    final List<dynamic> result =
        await methodChannel.invokeMethod('getActiveDownloads');
    return result
        .map((e) => DownloadTask.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
