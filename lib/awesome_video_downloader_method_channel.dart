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
  final _playableStatusStreams = <String, Stream<bool>>{};

  @override
  Future<String?> startDownload(DownloadConfig config) async {
    print('#### Flutter: Starting download with config: ${config.toMap()}');
    try {
      final taskId = await methodChannel.invokeMethod<String>(
        'startDownload',
        config.toMap(),
      );
      print('#### Flutter: Download started with taskId: $taskId');
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
    _eventChannels.remove('playable_$taskId');
    _progressStreams.remove(taskId);
    _playableStatusStreams.remove(taskId);
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
    print('#### Flutter: Setting up progress stream for taskId: $taskId');
    // Return existing stream if available
    if (_progressStreams.containsKey(taskId)) {
      print('#### Flutter: Returning existing progress stream');
      return _progressStreams[taskId]!;
    }

    // Create new event channel for this task
    final eventChannel =
        EventChannel('awesome_video_downloader/events/$taskId');
    _eventChannels[taskId] = eventChannel;
    print('#### Flutter: Created new event channel');

    // Create and store the stream
    final stream = eventChannel
        .receiveBroadcastStream({'taskId': taskId})
        .map((event) {
          print('#### Flutter: Received progress event: $event');
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
        onError: (error) {
          print('#### Flutter: Error in progress stream: $error');
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

  @override
  Future<String?> getDownloadedFilePath(String taskId) async {
    final String? path = await methodChannel.invokeMethod(
      'getDownloadedFilePath',
      {'taskId': taskId},
    );
    return path;
  }

  @override
  Future<bool> deleteDownloadedFile(String taskId) async {
    final bool result = await methodChannel.invokeMethod(
      'deleteDownloadedFile',
      {'taskId': taskId},
    );
    return result;
  }

  @override
  Stream<bool> getVideoPlayableStatus(String taskId) {
    // Return existing stream if available
    if (_playableStatusStreams.containsKey(taskId)) {
      return _playableStatusStreams[taskId]!;
    }

    // Create new event channel for this task's playable status
    final eventChannel =
        EventChannel('awesome_video_downloader/playable_status/$taskId');
    _eventChannels['playable_$taskId'] = eventChannel;

    // Create and store the stream
    final stream =
        eventChannel.receiveBroadcastStream({'taskId': taskId}).map((event) {
      if (event == null) return false;
      final Map<String, dynamic> data = Map<String, dynamic>.from(event as Map);
      return data['isPlayable'] as bool? ?? false;
    }).asBroadcastStream()
          ..listen(
            null,
            onDone: () {
              _eventChannels.remove('playable_$taskId');
              _playableStatusStreams.remove(taskId);
            },
          );

    _playableStatusStreams[taskId] = stream;
    return stream;
  }
}
