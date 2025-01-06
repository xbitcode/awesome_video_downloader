import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_method_channel.dart';
import 'package:awesome_video_downloader/models/download_config.dart';
import 'package:awesome_video_downloader/models/download_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelAwesomeVideoDownloader platform;
  late List<MethodCall> methodCalls;

  setUp(() {
    platform = MethodChannelAwesomeVideoDownloader();
    methodCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('awesome_video_downloader'),
      (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'startDownload':
            return 'test_id';
          case 'isVideoPlayableOffline':
            return true;
          case 'getActiveDownloads':
            return [
              {
                'taskId': 'test_id',
                'url': 'test_url',
                'title': 'test_title',
                'status': 1,
                'progress': 50.0,
              }
            ];
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('awesome_video_downloader'), null);
  });

  group('startDownload', () {
    test('passes correct parameters', () async {
      final config = DownloadConfig(
        url: 'test_url',
        title: 'test_title',
        minimumBitrate: 5000000,
        prefersHDR: true,
        prefersMultichannel: true,
        additionalOptions: {'key': 'value'},
      );

      await platform.startDownload(config);

      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, 'startDownload');
      expect(methodCalls.first.arguments, config.toMap());
    });

    test('returns task ID from platform', () async {
      final taskId = await platform.startDownload(
        DownloadConfig(url: 'test_url', title: 'test_title'),
      );
      expect(taskId, 'test_id');
    });
  });

  group('download management', () {
    const taskId = 'test_id';

    test('pauseDownload sends correct method call', () async {
      await platform.pauseDownload(taskId);
      expect(methodCalls.last.method, 'pauseDownload');
      expect(methodCalls.last.arguments, {'taskId': taskId});
    });

    test('resumeDownload sends correct method call', () async {
      await platform.resumeDownload(taskId);
      expect(methodCalls.last.method, 'resumeDownload');
      expect(methodCalls.last.arguments, {'taskId': taskId});
    });

    test('cancelDownload sends correct method call', () async {
      await platform.cancelDownload(taskId);
      expect(methodCalls.last.method, 'cancelDownload');
      expect(methodCalls.last.arguments, {'taskId': taskId});
    });
  });

  group('getActiveDownloads', () {
    test('correctly parses platform response', () async {
      final downloads = await platform.getActiveDownloads();

      expect(downloads, hasLength(1));
      expect(downloads.first.taskId, 'test_id');
      expect(downloads.first.url, 'test_url');
      expect(downloads.first.title, 'test_title');
      expect(downloads.first.status, DownloadStatus.downloading);
      expect(downloads.first.progress, 50.0);
    });
  });

  group('getDownloadProgress', () {
    test('emits progress updates from event channel', () async {
      final mockData = {
        'taskId': 'test_id',
        'progress': 50.0,
        'bytesDownloaded': 5000,
        'totalBytes': 10000,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'awesome_video_downloader/events',
        const StandardMethodCodec().encodeSuccessEnvelope(mockData),
        (ByteData? reply) {},
      );

      final progress = await platform.getDownloadProgress('test_id').first;

      expect(progress.taskId, 'test_id');
      expect(progress.progress, 50.0);
      expect(progress.bytesDownloaded, 5000);
      expect(progress.totalBytes, 10000);
    });

    test('handles null values gracefully', () async {
      final mockData = {
        'taskId': 'test_id',
        'progress': null,
        'bytesDownloaded': null,
        'totalBytes': null,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'awesome_video_downloader/events',
        const StandardMethodCodec().encodeSuccessEnvelope(mockData),
        (ByteData? reply) {},
      );

      final progress = await platform.getDownloadProgress('test_id').first;

      expect(progress.taskId, 'test_id');
      expect(progress.progress, 0.0);
      expect(progress.bytesDownloaded, 0);
      expect(progress.totalBytes, 0);
    });

    test('handles cancellation gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'awesome_video_downloader/events',
        null,
        (ByteData? reply) {},
      );

      final progress = await platform.getDownloadProgress('test_id').first;

      expect(progress.taskId, 'test_id');
      expect(progress.isCancelled, true);
      expect(progress.progress, 0.0);
      expect(progress.bytesDownloaded, 0);
      expect(progress.totalBytes, 0);
    });

    test('handles error events', () async {
      final mockError = {
        'taskId': 'test_id',
        'error': 'Download failed',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'awesome_video_downloader/events',
        const StandardMethodCodec().encodeSuccessEnvelope(mockError),
        (ByteData? reply) {},
      );

      expect(
        platform.getDownloadProgress('test_id').first,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Download failed'),
        )),
      );
    });

    group('handles cancellation', () {
      test('handles explicit cancellation gracefully', () async {
        final mockData = {
          'taskId': 'test_id',
          'status': 'cancelled',
        };

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'awesome_video_downloader/events',
          const StandardMethodCodec().encodeSuccessEnvelope(mockData),
          (ByteData? reply) {},
        );

        final progress = await platform.getDownloadProgress('test_id').first;
        expect(progress.isCancelled, true);
      });

      test('handles null event as cancellation', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'awesome_video_downloader/events',
          null,
          (ByteData? reply) {},
        );

        final progress = await platform.getDownloadProgress('test_id').first;
        expect(progress.isCancelled, true);
      });

      test('handles error-based cancellation', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'awesome_video_downloader/events',
          const StandardMethodCodec().encodeErrorEnvelope(
            code: 'ERROR',
            message: 'cancelled',
          ),
          (ByteData? reply) {},
        );

        final progress = await platform.getDownloadProgress('test_id').first;
        expect(progress.isCancelled, true);
      });
    });
  });

  group('isVideoPlayableOffline', () {
    test('sends correct method call', () async {
      await platform.isVideoPlayableOffline('test_id');
      expect(methodCalls.last.method, 'isVideoPlayableOffline');
      expect(methodCalls.last.arguments, {'taskId': 'test_id'});
    });

    test('returns platform response', () async {
      final isPlayable = await platform.isVideoPlayableOffline('test_id');
      expect(isPlayable, true);
    });
  });
}
