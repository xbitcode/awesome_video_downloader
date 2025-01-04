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

  @override
  Future<List<Map<String, dynamic>>> getAvailableQualities(String url) async {
    if (!url.startsWith('http')) {
      throw ArgumentError('Invalid URL');
    }

    return [
      {
        'id': '1080p',
        'width': 1920,
        'height': 1080,
        'bitrate': 5000000,
        'codec': 'h264',
        'isHDR': true,
        'label': 'Full HD',
      },
      {
        'id': '720p',
        'width': 1280,
        'height': 720,
        'bitrate': 2500000,
        'codec': 'h264',
        'isHDR': false,
        'label': '720p',
      },
    ];
  }
}

const String testUrl =
    "https://meta.vcdn.biz/ae6a3779fc0e85c73bd18c5a28f2f4b6_mgg/vod/hls/b/450_900_1350_1500_2000_5000/"
    "u_sid/0/o/202638611/rsid/e24fa7d0-750d-42e6-8132-849ef48a4aba/u_uid/806672782/u_vod/1/"
    "u_device/24seven_uz/u_devicekey/_24seven_uz_test/u_did/MTo4MDY2NzI3ODI6MTczMjA5MzYyMjo6MWI0NzYxOGViZmZjZjdhN2Q5ZWFiNzU4YWQzNmQ2YTA=/"
    "a/0/type.amlst/playlist.m3u8";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AwesomeVideoDownloaderPlatform initialPlatform =
      AwesomeVideoDownloaderPlatform.instance;

  setUp(() async {
    AwesomeVideoDownloaderPlatform.instance =
        MockAwesomeVideoDownloaderPlatform();
    await AwesomeVideoDownloaderPlatform.instance.initialize();
  });

  test('$MethodChannelAwesomeVideoDownloader is the default instance', () {
    expect(
        initialPlatform, isInstanceOf<MethodChannelAwesomeVideoDownloader>());
  });

  group('AwesomeVideoDownloader', () {
    late AwesomeVideoDownloader downloader;
    late MockAwesomeVideoDownloaderPlatform fakePlatform;

    setUp(() async {
      fakePlatform = MockAwesomeVideoDownloaderPlatform();
      AwesomeVideoDownloaderPlatform.instance = fakePlatform;
      downloader = AwesomeVideoDownloader();
      await downloader.initialize();
    });

    test('startDownload', () async {
      final downloadId = await downloader.startDownload(
        url: testUrl,
        fileName: 'video.mp4',
        format: 'mp4',
      );
      expect(downloadId, 'mock_download_id');
    });

    test('startDownload with invalid URL', () {
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

    test('DownloadProgress speed formatting', () {
      const progress = DownloadProgress(
        id: 'test_id',
        progress: 0.5,
        bytesDownloaded: 1024 * 1024, // 1 MB
        totalBytes: 2 * 1024 * 1024, // 2 MB
        speed: 1024 * 1024.0, // 1 MB/s
        state: DownloadState.downloading,
      );

      expect(progress.formattedSpeed, '1.0 MB/s');
      expect(progress.speedInMBps, 1.0);
      expect(progress.speedInKBps, 1024.0);

      const slowProgress = DownloadProgress(
        id: 'test_id',
        progress: 0.5,
        bytesDownloaded: 1024,
        totalBytes: 2048,
        speed: 512.0, // 512 B/s
        state: DownloadState.downloading,
      );

      expect(slowProgress.formattedSpeed, '512.0 B/s');
      expect(slowProgress.speedInMBps, closeTo(0.00048828125, 0.0000001));
      expect(slowProgress.speedInKBps, 0.5);
    });

    test('VideoQuality formatting', () {
      const quality = VideoQuality(
        id: 'test_quality',
        width: 1920,
        height: 1080,
        bitrate: 5000000, // 5 Mbps
        codec: 'h264',
        isHDR: true,
        label: 'Full HD',
      );

      expect(quality.resolution, equals('1920x1080'));
      expect(quality.bitrateString, equals('5.0 Mbps'));
      expect(quality.label, equals('Full HD'));

      // Test default label
      const autoLabelQuality = VideoQuality(
        id: 'auto_label',
        width: 1280,
        height: 720,
        bitrate: 2500000,
      );
      expect(autoLabelQuality.label, equals('720p'));
    });

    test('getAvailableQualities', () async {
      final qualities = await downloader.getAvailableQualities(testUrl);

      expect(qualities, isNotEmpty);
      expect(
        qualities.first,
        isA<VideoQuality>()
            .having((q) => q.width, 'width', greaterThan(0))
            .having((q) => q.height, 'height', greaterThan(0))
            .having((q) => q.bitrate, 'bitrate', greaterThan(0))
            .having((q) => q.codec, 'codec', isNotEmpty)
            .having((q) => q.label, 'label', isNotEmpty),
      );
    });

    test('getAvailableQualities with invalid URL', () {
      expect(
        () => downloader.getAvailableQualities('invalid_url'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
