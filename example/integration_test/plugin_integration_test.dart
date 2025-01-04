// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:async';

import 'package:awesome_video_downloader_example/main.dart';
import 'package:flutter/material.dart';
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

    testWidgets('Download speed calculation', (tester) async {
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'speed_test.mp4',
        format: 'mp4',
      );

      double? lastSpeed;
      int progressUpdates = 0;

      // Monitor progress for a few seconds
      await for (final progress in downloader.getDownloadProgress(downloadId)) {
        progressUpdates++;

        // Verify speed is being calculated
        expect(progress.speed, isNonNegative);

        if (lastSpeed != null) {
          // Speed should be somewhat consistent (not jumping wildly)
          expect(
            (progress.speed - lastSpeed).abs(),
            lessThan(lastSpeed * 2), // Allow up to 2x variation
          );
        }

        lastSpeed = progress.speed;

        // Print speed information for debugging
        print('Speed: ${progress.formattedSpeed}');
        print('Progress: ${(progress.progress * 100).toStringAsFixed(1)}%');
        print('Downloaded: ${progress.formattedSize}');

        // Break after a few updates or completion
        if (progressUpdates >= 5 || progress.isCompleted) break;
      }

      // Verify we got some progress updates
      expect(progressUpdates, greaterThan(0));
      expect(lastSpeed, isNotNull);
    });

    testWidgets('Quality selection workflow', (tester) async {
      // Get available qualities
      final qualities = await downloader.getAvailableQualities(testMp4Url);
      expect(qualities, isNotEmpty);

      // Select highest quality
      final highestQuality =
          qualities.reduce((a, b) => a.bitrate > b.bitrate ? a : b);

      // Start download with selected quality
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'quality_test.mp4',
        format: 'mp4',
        options: VideoDownloadOptions(
          minimumBitrate: highestQuality.bitrate,
          maximumBitrate: highestQuality.bitrate,
          preferHDR: highestQuality.isHDR,
        ),
      );

      expect(downloadId, isNotEmpty);

      // Monitor progress
      final progress = await downloader.getDownloadProgress(downloadId).first;
      expect(progress.state, equals(DownloadState.downloading));
    });

    testWidgets('Quality selection UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QualitySelectionDialog(
            qualities: [
              VideoQuality(
                id: '1080p',
                width: 1920,
                height: 1080,
                bitrate: 5000000,
                isHDR: true,
                label: 'Full HD',
              ),
              VideoQuality(
                id: '720p',
                width: 1280,
                height: 720,
                bitrate: 2500000,
                label: '720p',
              ),
            ],
          ),
        ),
      );

      // Verify UI elements
      expect(find.text('Select Quality'), findsOneWidget);
      expect(find.text('Full HD (5.0 Mbps)'), findsOneWidget);
      expect(find.text('720p (2.5 Mbps)'), findsOneWidget);
      expect(find.text('HDR'), findsOneWidget);
      expect(find.text('1920x1080'), findsOneWidget);
      expect(find.text('1280x720'), findsOneWidget);

      // Test selection
      await tester.tap(find.text('Full HD (5.0 Mbps)'));
      await tester.pumpAndSettle();

      // Dialog should be closed with selected quality
      expect(find.byType(QualitySelectionDialog), findsNothing);
    });
  });
}
