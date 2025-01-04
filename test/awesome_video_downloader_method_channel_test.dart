import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';
import 'package:awesome_video_downloader/awesome_video_downloader_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAwesomeVideoDownloader();
  const channel = MethodChannel('awesome_video_downloader');
  const eventChannel = EventChannel('awesome_video_downloader/events');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return null;
          case 'startDownload':
            return 'test_download_id';
          case 'pauseDownload':
          case 'resumeDownload':
          case 'cancelDownload':
            return null;
          case 'getDownloadStatus':
            return {
              'id': 'test_download_id',
              'state': DownloadState.downloading.name,
              'bytesDownloaded': 1024,
              'totalBytes': 2048,
              'error': null,
              'filePath': '/path/to/file.mp4',
            };
          case 'getAllDownloads':
            return [
              {
                'id': 'test_download_id',
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
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize', () async {
    await platform.initialize();
  });

  test('startDownload', () async {
    final downloadId = await platform.startDownload(
      url: 'https://example.com/video.mp4',
      fileName: 'video.mp4',
      format: 'mp4',
    );
    expect(downloadId, 'test_download_id');
  });

  test('pauseDownload', () async {
    await platform.pauseDownload('test_download_id');
  });

  test('resumeDownload', () async {
    await platform.resumeDownload('test_download_id');
  });

  test('cancelDownload', () async {
    await platform.cancelDownload('test_download_id');
  });

  test('getDownloadStatus', () async {
    final status = await platform.getDownloadStatus('test_download_id');
    expect(status, {
      'id': 'test_download_id',
      'state': DownloadState.downloading.name,
      'bytesDownloaded': 1024,
      'totalBytes': 2048,
      'error': null,
      'filePath': '/path/to/file.mp4',
    });
  });

  test('getAllDownloads', () async {
    final downloads = await platform.getAllDownloads();
    expect(downloads.length, 1);
    expect(downloads[0]['id'], 'test_download_id');
    expect(downloads[0]['format'], 'mp4');
    expect(downloads[0]['state'], DownloadState.downloading.name);
  });

  test('getDownloadProgress stream', () async {
    // Setup mock event channel handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      eventChannel.name,
      (ByteData? message) async {
        // Send test event immediately
        final progress = {
          'id': 'test_download_id',
          'progress': 0.5,
          'bytesDownloaded': 1024,
          'totalBytes': 2048,
          'speed': 512.0,
          'state': DownloadState.downloading.name,
          'filePath': '/path/to/file.mp4',
        };

        // Send event through platform channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          eventChannel.name,
          const StandardMethodCodec().encodeSuccessEnvelope(progress),
          (_) {},
        );

        // Return success for the listen call
        return null;
      },
    );

    // Wait for the first event
    final event = await platform.getDownloadProgress('test_download_id').first;

    // Verify the event data
    expect(
      event,
      allOf([
        containsPair('id', 'test_download_id'),
        containsPair('progress', 0.5),
        containsPair('state', DownloadState.downloading.name),
      ]),
    );
  });

  test('getAvailableQualities', () async {
    final qualities = await platform.getAvailableQualities(
      'https://example.com/video.mp4',
    );
    expect(qualities, isA<List<Map<String, dynamic>>>());
    expect(qualities, isNotEmpty);
    expect(
      qualities.first,
      containsPair('height', greaterThan(0)),
    );
  });
}
