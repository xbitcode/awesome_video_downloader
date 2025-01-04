// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Plugin Integration Tests', () {
    late AwesomeVideoDownloader downloader;

    // Test URLs
    const testMp4Url =
        'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4';
    const testHlsUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

    setUp(() async {
      downloader = AwesomeVideoDownloader();
      await downloader.initialize();
    });

    testWidgets('Download MP4 video', (tester) async {
      String? downloadId;
      DownloadProgress? lastProgress;
      bool downloadCompleted = false;

      // Start download
      downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'test_video.mp4',
        format: 'mp4',
      );
      expect(downloadId, isNotEmpty);

      // Monitor progress
      final completer = Completer<void>();
      final subscription = downloader.getDownloadProgress(downloadId).listen(
        (progress) {
          lastProgress = progress;
          if (progress.isCompleted) {
            downloadCompleted = true;
            completer.complete();
          }
        },
        onError: completer.completeError,
      );

      // Wait for download to complete or timeout
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 30)),
      ]);

      await subscription.cancel();

      // Verify download status
      if (downloadCompleted) {
        expect(lastProgress?.state, equals(DownloadState.completed));
        expect(lastProgress?.progress, equals(1.0));
        expect(lastProgress?.filePath, isNotNull);
      }

      final status = await downloader.getDownloadStatus(downloadId);
      expect(
          status.state,
          anyOf(equals(DownloadState.completed),
              equals(DownloadState.downloading)));
      expect(status.bytesDownloaded, greaterThan(0));

      // Check if file exists in downloads list
      final downloads = await downloader.getAllDownloads();
      expect(downloads, isNotEmpty);
      final download = downloads.firstWhere((d) => d.id == downloadId);
      expect(download.fileName, equals('test_video.mp4'));
    });

    testWidgets('Download HLS stream with options', (tester) async {
      final downloadId = await downloader.startDownload(
        url: testHlsUrl,
        fileName: 'test_stream.m3u8',
        format: 'hls',
        options: VideoDownloadOptions(
          minimumBitrate: 800000,
          preferHDR: true,
          preferMultichannel: true,
        ),
      );

      expect(downloadId, isNotEmpty);

      // Monitor initial progress
      final progress = await downloader.getDownloadProgress(downloadId).first;
      expect(progress.state, equals(DownloadState.downloading));
      expect(progress.bytesDownloaded, greaterThanOrEqualTo(0));
    });

    testWidgets('Pause and resume download', (tester) async {
      // Start download
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'pause_resume_test.mp4',
        format: 'mp4',
      );

      // Wait for download to start
      await Future.delayed(const Duration(seconds: 2));

      // Pause download
      await downloader.pauseDownload(downloadId);
      final pausedStatus = await downloader.getDownloadStatus(downloadId);
      expect(pausedStatus.state, equals(DownloadState.paused));

      // Resume download
      await downloader.resumeDownload(downloadId);
      final resumedStatus = await downloader.getDownloadStatus(downloadId);
      expect(
          resumedStatus.state,
          anyOf(equals(DownloadState.downloading),
              equals(DownloadState.completed)));
    });

    testWidgets('Cancel download', (tester) async {
      // Start download
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'cancel_test.mp4',
        format: 'mp4',
      );

      // Wait for download to start
      await Future.delayed(const Duration(seconds: 2));

      // Cancel download
      await downloader.cancelDownload(downloadId);

      // Verify download was cancelled
      final downloads = await downloader.getAllDownloads();
      expect(downloads.any((d) => d.id == downloadId), isFalse);
    });

    testWidgets('Error handling - invalid URL', (tester) async {
      expect(
        () => downloader.startDownload(
          url: 'invalid_url',
          fileName: 'error_test.mp4',
          format: 'mp4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('Progress updates accuracy', (tester) async {
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'progress_test.mp4',
        format: 'mp4',
      );

      double? lastProgress;
      await for (final progress in downloader.getDownloadProgress(downloadId)) {
        if (lastProgress != null) {
          expect(progress.progress, greaterThanOrEqualTo(lastProgress));
        }
        lastProgress = progress.progress;

        if (progress.isCompleted) break;
        if (progress.progress == 0.0) continue;

        // Verify progress calculation
        expect(
          progress.progress,
          equals(progress.bytesDownloaded / progress.totalBytes),
        );
      }
    });

    testWidgets('VideoDownloadOptions validation', (tester) async {
      // Test invalid bitrate values
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

      // Test valid options
      final options = VideoDownloadOptions(
        minimumBitrate: 1000000,
        maximumBitrate: 2000000,
        preferHDR: true,
        preferMultichannel: true,
        headers: {'Authorization': 'Bearer test'},
      );

      expect(options.minimumBitrate, equals(1000000));
      expect(options.maximumBitrate, equals(2000000));
      expect(options.preferHDR, isTrue);
      expect(options.preferMultichannel, isTrue);
      expect(options.headers?['Authorization'], equals('Bearer test'));
    });
  });
}
