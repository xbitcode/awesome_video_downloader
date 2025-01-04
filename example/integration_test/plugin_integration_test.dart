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
      // Start download
      final downloadId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'test_video.mp4',
        format: 'mp4',
      );
      expect(downloadId, isNotEmpty);

      // Monitor initial progress
      final progress = await downloader.getDownloadProgress(downloadId).first;
      expect(progress.progress, greaterThanOrEqualTo(0));
      expect(progress.speed, greaterThanOrEqualTo(0));

      // Check status
      final status = await downloader.getDownloadStatus(downloadId);
      expect(status.state, equals(DownloadState.downloading));
      expect(status.error, isNull);

      // Get download info
      final downloads = await downloader.getAllDownloads();
      final download = downloads.firstWhere((d) => d.id == downloadId);
      expect(download.fileName, equals('test_video.mp4'));
      expect(download.format, equals('mp4'));
    });

    testWidgets('Quality selection workflow', (tester) async {
      // Get available qualities
      final qualities = await downloader.getAvailableQualities(testHlsUrl);
      expect(qualities, isNotEmpty);

      // Select highest quality
      final highestQuality =
          qualities.reduce((a, b) => a.bitrate > b.bitrate ? a : b);

      // Start download with selected quality
      final downloadId = await downloader.startDownload(
        url: testHlsUrl,
        fileName: 'quality_test.m3u8',
        format: 'hls',
        options: VideoDownloadOptions(
          minimumBitrate: highestQuality.bitrate,
          maximumBitrate: highestQuality.bitrate,
          preferHDR: highestQuality.isHDR,
        ),
      );

      expect(downloadId, isNotEmpty);

      // Check initial status
      final status = await downloader.getDownloadStatus(downloadId);
      expect(status.state, equals(DownloadState.downloading));

      // Monitor progress
      final progress = await downloader.getDownloadProgress(downloadId).first;
      expect(progress.progress, greaterThanOrEqualTo(0));
      expect(progress.speed, greaterThanOrEqualTo(0));
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
      expect(resumedStatus.state, equals(DownloadState.downloading));
    });

    testWidgets('Duplicate download handling', (tester) async {
      // Start first download
      final firstId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'duplicate_test.mp4',
        format: 'mp4',
      );

      // Try to download same video
      final secondId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'duplicate_test_2.mp4',
        format: 'mp4',
      );

      // Should return the same ID
      expect(secondId, equals(firstId));

      // Allow duplicate
      final thirdId = await downloader.startDownload(
        url: testMp4Url,
        fileName: 'duplicate_test_3.mp4',
        format: 'mp4',
        allowDuplicates: true,
      );

      // Should get new ID
      expect(thirdId, isNot(equals(firstId)));
    });

    testWidgets('Quality selection UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QualitySelectionDialog(
            qualities: const [
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

      expect(find.text('Select Quality'), findsOneWidget);
      expect(find.text('Full HD (5.0 Mbps)'), findsOneWidget);
      expect(find.text('720p (2.5 Mbps)'), findsOneWidget);
      expect(find.text('HDR'), findsOneWidget);
      expect(find.text('1920x1080'), findsOneWidget);
      expect(find.text('1280x720'), findsOneWidget);

      await tester.tap(find.text('Full HD (5.0 Mbps)'));
      await tester.pumpAndSettle();

      expect(find.byType(QualitySelectionDialog), findsNothing);
    });
  });
}
