// ignore_for_file: public_member_api_docs, sort_constructors_first
// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'awesome_video_downloader_platform_interface.dart';

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// A Flutter plugin for downloading videos in various formats (HLS, DASH, MP4)
class AwesomeVideoDownloader {
  bool _isInitialized = false;

  /// Initialize the downloader
  ///
  /// This must be called before using any other methods.
  /// Make sure to call [WidgetsFlutterBinding.ensureInitialized()] before this.
  ///
  /// Throws:
  /// - [StateError] if called multiple times
  /// - [StateError] if Flutter bindings are not initialized
  Future<void> initialize() async {
    if (_isInitialized) {
      throw StateError('AwesomeVideoDownloader is already initialized');
    }

    // Check if Flutter bindings are initialized
    if (!_isFlutterBindingInitialized()) {
      throw StateError(
        'Flutter bindings are not initialized. '
        'Call WidgetsFlutterBinding.ensureInitialized() before initialize().',
      );
    }

    try {
      await AwesomeVideoDownloaderPlatform.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      throw StateError('Failed to initialize AwesomeVideoDownloader: $e');
    }
  }

  // Check if Flutter bindings are initialized
  bool _isFlutterBindingInitialized() {
    try {
      // Just accessing instance will throw if bindings aren't initialized
      WidgetsBinding.instance;
      return true;
    } on StateError {
      return false;
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'AwesomeVideoDownloader must be initialized before use. '
        'Call initialize() first.',
      );
    }
  }

  /// Start a new video download
  ///
  /// Parameters:
  /// - [url]: The URL of the video to download
  /// - [fileName]: The name to save the file as
  /// - [format]: The format of the video ('mp4', 'hls', or 'dash')
  /// - [options]: Optional download configuration
  /// - [allowDuplicates]: Whether to allow downloading the same video multiple times
  ///
  /// Returns:
  /// - The download ID (either new or existing if the video is already being downloaded)
  /// - Throws [StateError] if video is already downloaded and [allowDuplicates] is false
  Future<String> startDownload({
    required String url,
    required String fileName,
    required String format,
    VideoDownloadOptions? options,
    bool allowDuplicates = false,
  }) async {
    _checkInitialized();

    if (!_isValidUrl(url)) {
      throw ArgumentError('Invalid URL provided');
    }

    if (!_isValidFormat(format)) {
      throw ArgumentError('Invalid format. Supported formats: mp4, hls, dash');
    }

    // Check for existing download
    if (!allowDuplicates) {
      final existing = await checkExistingDownload(url);
      if (existing != null) {
        return existing.id;
      }
    }

    return AwesomeVideoDownloaderPlatform.instance.startDownload(
      url: url,
      fileName: fileName,
      format: format.toLowerCase(),
      options: options?.toMap(),
    );
  }

  /// Pause an active download
  Future<void> pauseDownload(String downloadId) {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    return AwesomeVideoDownloaderPlatform.instance.pauseDownload(downloadId);
  }

  /// Resume a paused download
  Future<void> resumeDownload(String downloadId) {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    return AwesomeVideoDownloaderPlatform.instance.resumeDownload(downloadId);
  }

  /// Cancel and remove a download
  Future<void> cancelDownload(String downloadId) {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    return AwesomeVideoDownloaderPlatform.instance.cancelDownload(downloadId);
  }

  /// Stream download status updates
  Stream<DownloadStatus> getDownloadStatus(String downloadId) {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    return AwesomeVideoDownloaderPlatform.instance
        .getDownloadStatus(downloadId)
        .map((status) => DownloadStatus.fromMap(status));
  }

  /// Get a list of all downloads (active and completed)
  Future<List<DownloadInfo>> getAllDownloads() async {
    _checkInitialized();

    final downloads =
        await AwesomeVideoDownloaderPlatform.instance.getAllDownloads();
    return downloads.map((download) => DownloadInfo.fromMap(download)).toList();
  }

  /// Stream download progress updates
  Stream<DownloadProgress> getDownloadProgress(String downloadId) {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    return AwesomeVideoDownloaderPlatform.instance
        .getDownloadProgress(downloadId)
        .map((progress) => DownloadProgress.fromMap(progress));
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  bool _isValidFormat(String format) {
    return ['mp4', 'hls', 'dash'].contains(format.toLowerCase());
  }

  /// Get available qualities for a video URL
  Future<List<VideoQuality>> getAvailableQualities(String url) async {
    _checkInitialized();

    if (!_isValidUrl(url)) {
      throw ArgumentError('Invalid URL provided');
    }

    final qualities = await AwesomeVideoDownloaderPlatform.instance
        .getAvailableQualities(url);
    return qualities.map((q) => VideoQuality.fromMap(q)).toList();
  }

  /// Check if a video has already been downloaded
  Future<DownloadInfo?> checkExistingDownload(String url) async {
    _checkInitialized();

    if (!_isValidUrl(url)) {
      throw ArgumentError('Invalid URL provided');
    }

    final downloads = await getAllDownloads();
    return downloads.firstWhereOrNull(
      (download) =>
          download.url == url &&
          (download.isCompleted || download.isDownloading),
    );
  }
}

/// Configuration options for video downloads
class VideoDownloadOptions extends Equatable {
  /// Minimum required bitrate in bits per second
  final int? minimumBitrate;

  /// Maximum allowed bitrate in bits per second
  final int? maximumBitrate;

  /// Whether to prefer HDR content when available
  final bool preferHDR;

  /// Whether to prefer multichannel audio when available
  final bool preferMultichannel;

  /// Custom HTTP headers for the download request
  final Map<String, String>? headers;

  /// Creates a new VideoDownloadOptions instance
  VideoDownloadOptions({
    this.minimumBitrate,
    this.maximumBitrate,
    this.preferHDR = false,
    this.preferMultichannel = false,
    this.headers,
  }) {
    if (minimumBitrate != null && minimumBitrate! < 0) {
      throw ArgumentError('minimumBitrate cannot be negative');
    }
    if (maximumBitrate != null && maximumBitrate! < 0) {
      throw ArgumentError('maximumBitrate cannot be negative');
    }
    if (minimumBitrate != null &&
        maximumBitrate != null &&
        minimumBitrate! > maximumBitrate!) {
      throw ArgumentError(
          'minimumBitrate cannot be greater than maximumBitrate');
    }
  }

  /// Creates a copy of this instance with the given fields replaced with new values
  VideoDownloadOptions copyWith({
    int? minimumBitrate,
    int? maximumBitrate,
    bool? preferHDR,
    bool? preferMultichannel,
    Map<String, String>? headers,
  }) {
    return VideoDownloadOptions(
      minimumBitrate: minimumBitrate ?? this.minimumBitrate,
      maximumBitrate: maximumBitrate ?? this.maximumBitrate,
      preferHDR: preferHDR ?? this.preferHDR,
      preferMultichannel: preferMultichannel ?? this.preferMultichannel,
      headers: headers ?? this.headers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minimumBitrate': minimumBitrate,
      'maximumBitrate': maximumBitrate,
      'preferHDR': preferHDR,
      'preferMultichannel': preferMultichannel,
      'headers': headers,
    };
  }

  @override
  List<Object?> get props {
    return [
      minimumBitrate,
      maximumBitrate,
      preferHDR,
      preferMultichannel,
      headers,
    ];
  }
}

/// Represents the current state of a download
enum DownloadState {
  notStarted,
  downloading,
  paused,
  completed,
  failed,
  cancelled;

  String toJson() => name;

  static DownloadState fromJson(String json) {
    return DownloadState.values.firstWhere(
      (e) => e.name == json,
      orElse: () => DownloadState.notStarted,
    );
  }
}

/// Status information for a download
class DownloadStatus {
  final String id;
  final DownloadState state;
  final String? error;

  const DownloadStatus({
    required this.id,
    required this.state,
    this.error,
  });

  bool get isCompleted => state == DownloadState.completed;
  bool get isPaused => state == DownloadState.paused;
  bool get isFailed => state == DownloadState.failed;
  bool get isDownloading => state == DownloadState.downloading;

  factory DownloadStatus.fromMap(Map<String, dynamic> map) {
    return DownloadStatus(
      id: map['id'] as String,
      state: DownloadState.fromJson(map['state'] as String),
      error: map['error'] as String?,
    );
  }
}

/// Detailed download information
class DownloadInfo {
  final String id;
  final String url;
  final String fileName;
  final String format;
  final DateTime createdAt;
  final DownloadState state;
  final int bytesDownloaded;
  final int totalBytes;
  final String? filePath;

  const DownloadInfo({
    required this.id,
    required this.url,
    required this.fileName,
    required this.format,
    required this.createdAt,
    required this.state,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.filePath,
  });

  String get formattedSize =>
      '${(bytesDownloaded / 1024 / 1024).toStringAsFixed(1)}/'
      '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';

  bool get isCompleted => state == DownloadState.completed;
  bool get isDownloading => state == DownloadState.downloading;

  factory DownloadInfo.fromMap(Map<String, dynamic> map) {
    return DownloadInfo(
      id: map['id'] as String,
      url: map['url'] as String,
      fileName: map['fileName'] as String,
      format: map['format'] as String,
      state: DownloadState.fromJson(map['state'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      bytesDownloaded: map['bytesDownloaded'] as int? ?? 0,
      totalBytes: map['totalBytes'] as int? ?? 0,
      filePath: map['filePath'] as String?,
    );
  }
}

/// Download progress information
class DownloadProgress {
  final String id;
  final double progress;
  final double speed;

  const DownloadProgress({
    required this.id,
    required this.progress,
    required this.speed,
  });

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';
  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  factory DownloadProgress.fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      id: map['id'] as String,
      progress: map['progress'] as double,
      speed: map['speed'] as double,
    );
  }
}

/// Represents a video quality option
class VideoQuality extends Equatable {
  final String id;
  final int width;
  final int height;
  final int bitrate;
  final String codec;
  final bool isHDR;
  final String label;

  const VideoQuality({
    required this.id,
    required this.width,
    required this.height,
    required this.bitrate,
    this.codec = 'h264',
    this.isHDR = false,
    String? label,
  }) : label = label ?? '${height}p';

  String get resolution => '${width}x$height';
  String get bitrateString => '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';

  VideoQuality copyWith({
    int? width,
    int? height,
    int? bitrate,
    String? codec,
    bool? isHDR,
    String? label,
  }) {
    return VideoQuality(
      id: id,
      width: width ?? this.width,
      height: height ?? this.height,
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      isHDR: isHDR ?? this.isHDR,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'width': width,
        'height': height,
        'bitrate': bitrate,
        'codec': codec,
        'isHDR': isHDR,
        'label': label,
      };

  factory VideoQuality.fromMap(Map<String, dynamic> map) {
    return VideoQuality(
      id: map['id'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      bitrate: map['bitrate'] as int,
      codec: map['codec'] as String? ?? 'h264',
      isHDR: map['isHDR'] as bool? ?? false,
      label: map['label'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, width, height, bitrate, codec, isHDR, label];
}
