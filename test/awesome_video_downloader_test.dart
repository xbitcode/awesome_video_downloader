import 'package:flutter_test/flutter_test.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_platform_interface.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAwesomeVideoDownloaderPlatform
    with MockPlatformInterfaceMixin
    implements AwesomeVideoDownloaderPlatform {
  @override
  Future<void> initialize() async {}

  @override
  Future<String> startDownload({
    required String url,
    required String fileName,
    required String format,
    Map<String, dynamic>? options,
  }) async {
    return 'mock_download_id';
  }

  @override
  Future<void> pauseDownload(String downloadId) async {}

  @override
  Future<void> resumeDownload(String downloadId) async {}

  @override
  Future<void> cancelDownload(String downloadId) async {}

  @override
  Future<Map<String, dynamic>> getDownloadStatus(String downloadId) async {
    return {
      'id': downloadId,
      'state': DownloadState.downloading.name,
      'bytesDownloaded': 1024,
      'totalBytes': 2048,
      'error': null,
      'filePath': '/path/to/file.mp4',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    return [
      {
        'id': 'mock_download_id',
        'url': 'https://example.com/video.mp4',
        'fileName': 'video.mp4',
        'format': 'mp4',
        'state': DownloadState.downloading.name,
        'createdAt': DateTime.now().toIso8601String(),
        'bytesDownloaded': 1024,
        'totalBytes': 2048,
        'filePath': '/path/to/file.mp4',
      }
    ];
  }

  @override
  Stream<Map<String, dynamic>> getDownloadProgress(String downloadId) {
    return Stream.fromIterable([
      {
        'id': downloadId,
        'progress': 0.5,
        'bytesDownloaded': 1024,
        'totalBytes': 2048,
        'speed': 512.0,
        'state': DownloadState.downloading.name,
        'filePath': '/path/to/file.mp4',
      }
    ]);
  }
}

void main() {
  final AwesomeVideoDownloaderPlatform initialPlatform =
      AwesomeVideoDownloaderPlatform.instance;

  test('$MethodChannelAwesomeVideoDownloader is the default instance', () {
    expect(
        initialPlatform, isInstanceOf<MethodChannelAwesomeVideoDownloader>());
  });

  group('AwesomeVideoDownloader', () {
    late AwesomeVideoDownloader downloader;
    late MockAwesomeVideoDownloaderPlatform fakePlatform;

    setUp(() {
      fakePlatform = MockAwesomeVideoDownloaderPlatform();
      AwesomeVideoDownloaderPlatform.instance = fakePlatform;
      downloader = AwesomeVideoDownloader();
    });

    test('initialize', () async {
      await downloader.initialize();
    });

    test('startDownload', () async {
      final downloadId = await downloader.startDownload(
        url: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
        format: 'mp4',
      );
      expect(downloadId, 'mock_download_id');
    });

    test('startDownload with invalid URL', () async {
      expect(
        () => downloader.startDownload(
          url: 'invalid_url',
          fileName: 'video.mp4',
          format: 'mp4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('startDownload with invalid format', () async {
      expect(
        () => downloader.startDownload(
          url: 'https://example.com/video.mp4',
          fileName: 'video.mp4',
          format: 'invalid',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getDownloadStatus', () async {
      final status = await downloader.getDownloadStatus('mock_download_id');
      expect(status.id, 'mock_download_id');
      expect(status.state, DownloadState.downloading);
      expect(status.bytesDownloaded, 1024);
      expect(status.totalBytes, 2048);
      expect(status.error, null);
      expect(status.filePath, '/path/to/file.mp4');
    });

    test('getDownloadProgress', () async {
      final progress =
          await downloader.getDownloadProgress('mock_download_id').first;
      expect(progress.id, 'mock_download_id');
      expect(progress.progress, 0.5);
      expect(progress.bytesDownloaded, 1024);
      expect(progress.totalBytes, 2048);
      expect(progress.speed, 512.0);
      expect(progress.state, DownloadState.downloading);
      expect(progress.filePath, '/path/to/file.mp4');
    });

    test('VideoDownloadOptions validation', () {
      expect(
        () => VideoDownloadOptions(minimumBitrate: -1),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => VideoDownloadOptions(
          minimumBitrate: 2000000,
          maximumBitrate: 1000000,
        ),
        throwsA(isA<ArgumentError>()),
      );

      final options = VideoDownloadOptions(
        minimumBitrate: 1000000,
        maximumBitrate: 2000000,
        preferHDR: true,
        preferMultichannel: true,
      );

      expect(options.minimumBitrate, 1000000);
      expect(options.maximumBitrate, 2000000);
      expect(options.preferHDR, true);
      expect(options.preferMultichannel, true);
    });
  });
}
