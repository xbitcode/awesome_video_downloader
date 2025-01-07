import 'package:flutter_test/flutter_test.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_platform_interface.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_method_channel.dart';
import 'package:awesome_video_downloader/models/download_config.dart';
import 'package:awesome_video_downloader/models/download_task.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAwesomeVideoDownloaderPlatform
    with MockPlatformInterfaceMixin
    implements AwesomeVideoDownloaderPlatform {
  final List<String> activeDownloads = [];
  final Map<String, double> downloadProgress = {};

  @override
  Future<String?> startDownload(DownloadConfig config) async {
    final taskId = 'test_id_${activeDownloads.length}';
    activeDownloads.add(taskId);
    downloadProgress[taskId] = 0.0;
    return taskId;
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    if (!activeDownloads.contains(taskId)) {
      throw Exception('Download not found');
    }
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    if (!activeDownloads.contains(taskId)) {
      throw Exception('Download not found');
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    if (!activeDownloads.contains(taskId)) {
      throw Exception('Download not found');
    }
    activeDownloads.remove(taskId);
    downloadProgress.remove(taskId);
  }

  @override
  Future<List<DownloadTask>> getActiveDownloads() async {
    return activeDownloads
        .map((taskId) => DownloadTask(
              taskId: taskId,
              url: 'test_url',
              title: 'test_title',
              status: DownloadStatus.downloading,
              progress: downloadProgress[taskId] ?? 0.0,
            ))
        .toList();
  }

  @override
  Stream<DownloadProgress> getDownloadProgress(String taskId) {
    if (!activeDownloads.contains(taskId)) {
      return Stream.error('Download not found');
    }

    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      final progress = (count * 10.0).clamp(0.0, 100.0);
      downloadProgress[taskId] = progress;
      return DownloadProgress(
        taskId: taskId,
        progress: progress,
        bytesDownloaded: (progress * 1024).round(),
        totalBytes: 102400,
      );
    }).take(11); // Will emit progress from 0% to 100%
  }

  @override
  Future<bool> isVideoPlayableOffline(String taskId) async {
    return downloadProgress[taskId] == 100.0;
  }

  @override
  Future<String?> getDownloadedFilePath(String taskId) {
    // TODO: implement getDownloadedFilePath
    throw UnimplementedError();
  }

  @override
  Stream<bool> getVideoPlayableStatus(String taskId) {
    // TODO: implement getVideoPlayableStatus
    throw UnimplementedError();
  }
  
  @override
  Future<bool> deleteDownloadedFile(String taskId) {
    // TODO: implement deleteDownloadedFile
    throw UnimplementedError();
  }
}

void main() {
  late AwesomeVideoDownloader plugin;
  late MockAwesomeVideoDownloaderPlatform fakePlatform;

  setUp(() {
    fakePlatform = MockAwesomeVideoDownloaderPlatform();
    AwesomeVideoDownloaderPlatform.instance = fakePlatform;
    plugin = AwesomeVideoDownloader();
  });

  test('$MethodChannelAwesomeVideoDownloader is the default instance', () {
    expect(AwesomeVideoDownloaderPlatform.instance,
        isInstanceOf<MethodChannelAwesomeVideoDownloader>());
  });

  group('startDownload', () {
    test('returns task ID on successful download start', () async {
      final taskId = await plugin.startDownload(
        DownloadConfig(url: 'test_url', title: 'test_title'),
      );
      expect(taskId, isNotNull);
      expect(fakePlatform.activeDownloads, contains(taskId));
    });

    test('supports custom bitrate and HDR settings', () async {
      final taskId = await plugin.startDownload(
        DownloadConfig(
          url: 'test_url',
          title: 'test_title',
          minimumBitrate: 5000000,
          prefersHDR: true,
        ),
      );
      expect(taskId, isNotNull);
    });
  });

  group('download management', () {
    late String taskId;

    setUp(() async {
      taskId = await plugin.startDownload(
            DownloadConfig(url: 'test_url', title: 'test_title'),
          ) ??
          '';
    });

    test('can pause download', () async {
      await expectLater(plugin.pauseDownload(taskId), completes);
    });

    test('can resume download', () async {
      await expectLater(plugin.resumeDownload(taskId), completes);
    });

    test('can cancel download', () async {
      await plugin.cancelDownload(taskId);
      final downloads = await plugin.getActiveDownloads();
      expect(downloads, isEmpty);
    });

    test('throws when managing non-existent download', () async {
      const invalidTaskId = 'invalid_task_id';
      expect(plugin.pauseDownload(invalidTaskId), throwsException);
      expect(plugin.resumeDownload(invalidTaskId), throwsException);
      expect(plugin.cancelDownload(invalidTaskId), throwsException);
    });
  });

  group('download progress', () {
    test('emits progress updates', () async {
      final taskId = await plugin.startDownload(
            DownloadConfig(url: 'test_url', title: 'test_title'),
          ) ??
          '';

      final progressUpdates = await plugin
          .getDownloadProgress(taskId)
          .take(5)
          .map((event) => event.progress)
          .toList();

      expect(progressUpdates, hasLength(5));
      expect(progressUpdates.first, 0.0);
      expect(progressUpdates.last, greaterThan(progressUpdates.first));
    });

    test('reports bytes downloaded', () async {
      final taskId = await plugin.startDownload(
            DownloadConfig(url: 'test_url', title: 'test_title'),
          ) ??
          '';

      final progress = await plugin.getDownloadProgress(taskId).first;
      expect(progress.bytesDownloaded, isNonNegative);
      expect(progress.totalBytes, greaterThan(0));
    });
  });

  group('active downloads', () {
    test('returns list of active downloads', () async {
      // Start multiple downloads
      final taskIds = await Future.wait([
        plugin.startDownload(DownloadConfig(url: 'url1', title: 'title1')),
        plugin.startDownload(DownloadConfig(url: 'url2', title: 'title2')),
      ]);

      final downloads = await plugin.getActiveDownloads();
      expect(downloads, hasLength(2));
      expect(
        downloads.map((d) => d.taskId),
        containsAll(taskIds.whereType<String>()),
      );
    });

    test('updates after cancelling download', () async {
      final taskId = await plugin.startDownload(
            DownloadConfig(url: 'test_url', title: 'test_title'),
          ) ??
          '';

      await plugin.cancelDownload(taskId);
      final downloads = await plugin.getActiveDownloads();
      expect(downloads, isEmpty);
    });
  });

  group('offline playback', () {
    test('reports correct offline playability status', () async {
      final taskId = await plugin.startDownload(
            DownloadConfig(url: 'test_url', title: 'test_title'),
          ) ??
          '';

      // Initially not playable
      expect(await plugin.isVideoPlayableOffline(taskId), false);

      // Wait for download to complete
      await plugin.getDownloadProgress(taskId).last;

      // Should be playable after completion
      expect(await plugin.isVideoPlayableOffline(taskId), true);
    });
  });
}
