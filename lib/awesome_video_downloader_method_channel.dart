import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:awesome_video_downloader/models/download_task.dart';
import 'package:awesome_video_downloader/models/download_config.dart';
import 'awesome_video_downloader.dart';
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

  @override
  Future<String?> startDownload(DownloadConfig config) async {
    final taskId = await methodChannel.invokeMethod<String>(
      'startDownload',
      config.toMap(),
    );
    return taskId;
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'pauseDownload',
      {'taskId': taskId},
    );
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'resumeDownload',
      {'taskId': taskId},
    );
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    await methodChannel.invokeMethod<void>(
      'cancelDownload',
      {'taskId': taskId},
    );
    _eventChannels.remove(taskId);
    _progressStreams.remove(taskId);
  }

  @override
  Future<List<DownloadTask>> getActiveDownloads() async {
    final List<dynamic> result =
        await methodChannel.invokeMethod('getActiveDownloads');
    return result
        .map((e) => DownloadTask.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Stream<DownloadProgress> getDownloadProgress(String taskId) {
    // Return existing stream if available
    if (_progressStreams.containsKey(taskId)) {
      return _progressStreams[taskId]!;
    }

    // Create new event channel for this task
    final eventChannel =
        EventChannel('awesome_video_downloader/events/$taskId');
    _eventChannels[taskId] = eventChannel;

    // Create and store the stream
    final stream = eventChannel
        .receiveBroadcastStream({'taskId': taskId})
        .map((event) {
          if (event == null) {
            return DownloadProgress(
              taskId: taskId,
              progress: 0.0,
              bytesDownloaded: 0,
              totalBytes: 0,
              isCancelled: true,
            );
          }

          final Map<String, dynamic> data =
              Map<String, dynamic>.from(event as Map);

          // Strict task ID validation - must be present and match
          final eventTaskId = data['taskId'] as String?;
          if (eventTaskId == null || eventTaskId != taskId) {
            // Skip events that don't belong to this task
            return null;
          }

          // Handle authentication errors
          if (data.containsKey('error')) {
            final error = data['error'] as String;
            if (error.toLowerCase().contains('authentication')) {
              throw AuthenticationRequiredException(error);
            } else if (error.contains('NSURLErrorDomain error -1013')) {
              throw AuthenticationFailedException(
                  'Authentication failed or was cancelled by user');
            } else if (error.contains('cancelled')) {
              return DownloadProgress(
                taskId: taskId,
                progress: 0.0,
                bytesDownloaded: 0,
                totalBytes: 0,
                isCancelled: true,
              );
            }
            throw Exception(error);
          }

          // Handle explicit cancellation
          if (data['status'] == 'cancelled') {
            return DownloadProgress(
              taskId: taskId,
              progress: 0.0,
              bytesDownloaded: 0,
              totalBytes: 0,
              isCancelled: true,
            );
          }

          // Ensure all required fields are present and have correct types
          if (!data.containsKey('progress') ||
              !data.containsKey('bytesDownloaded') ||
              !data.containsKey('totalBytes')) {
            throw Exception('Invalid progress data received');
          }

          return DownloadProgress(
            taskId: taskId,
            progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
            bytesDownloaded: (data['bytesDownloaded'] as num?)?.toInt() ?? 0,
            totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
            isCancelled: false,
          );
        })
        .where((event) => event != null) // Filter out null events
        .cast<DownloadProgress>() // Cast to the correct type
        .asBroadcastStream()
      ..listen(
        null,
        onDone: () {
          _eventChannels.remove(taskId);
          _progressStreams.remove(taskId);
        },
      );

    _progressStreams[taskId] = stream;
    return stream;
  }

  @override
  Future<bool> isVideoPlayableOffline(String taskId) async {
    final bool result = await methodChannel.invokeMethod(
      'isVideoPlayableOffline',
      {'taskId': taskId},
    );
    return result;
  }
}
