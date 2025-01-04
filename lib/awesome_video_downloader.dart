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
  ///
  /// Returns the download ID that can be used to track the download
  Future<String> startDownload({
    required String url,
    required String fileName,
    required String format,
    VideoDownloadOptions? options,
  }) {
    _checkInitialized();

    if (!_isValidUrl(url)) {
      throw ArgumentError('Invalid URL provided');
    }

    if (!_isValidFormat(format)) {
      throw ArgumentError('Invalid format. Supported formats: mp4, hls, dash');
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

  /// Get the current status of a download
  Future<DownloadStatus> getDownloadStatus(String downloadId) async {
    _checkInitialized();

    if (downloadId.isEmpty) {
      throw ArgumentError('Download ID cannot be empty');
    }
    final status = await AwesomeVideoDownloaderPlatform.instance
        .getDownloadStatus(downloadId);
    return DownloadStatus.fromMap(status);
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

/// Base class for download information
abstract class BaseDownloadInfo extends Equatable {
  final String id;
  final DownloadState state;
  final int bytesDownloaded;
  final int totalBytes;
  final String? filePath;

  const BaseDownloadInfo({
    required this.id,
    required this.state,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.filePath,
  });

  bool get isCompleted => state == DownloadState.completed;
  bool get isPaused => state == DownloadState.paused;
  bool get isFailed => state == DownloadState.failed;
  bool get isDownloading => state == DownloadState.downloading;

  double get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;

  String get formattedSize =>
      '${(bytesDownloaded / 1024 / 1024).toStringAsFixed(1)}/${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Status information for a download
class DownloadStatus extends BaseDownloadInfo with EquatableMixin {
  final String? error;

  const DownloadStatus({
    required super.id,
    required super.state,
    required super.bytesDownloaded,
    required super.totalBytes,
    super.filePath,
    this.error,
  });

  DownloadStatus copyWith({
    DownloadState? state,
    int? bytesDownloaded,
    int? totalBytes,
    String? filePath,
    String? error,
  }) {
    return DownloadStatus(
      id: id,
      state: state ?? this.state,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
    );
  }

  factory DownloadStatus.fromMap(Map<String, dynamic> map) {
    return DownloadStatus(
      id: map['id'] as String,
      state: DownloadState.fromJson(map['state'] as String),
      bytesDownloaded: map['bytesDownloaded'] as int,
      totalBytes: map['totalBytes'] as int,
      filePath: map['filePath'] as String?,
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'state': state.toJson(),
        'bytesDownloaded': bytesDownloaded,
        'totalBytes': totalBytes,
        if (filePath != null) 'filePath': filePath,
        if (error != null) 'error': error,
      };

  @override
  List<Object?> get props => [
        id,
        state,
        bytesDownloaded,
        totalBytes,
        filePath,
        error,
      ];
}

/// Detailed information about a download
class DownloadInfo extends BaseDownloadInfo {
  final String url;
  final String fileName;
  final String format;
  final DateTime createdAt;

  const DownloadInfo({
    required super.id,
    required this.url,
    required this.fileName,
    required this.format,
    required super.state,
    required this.createdAt,
    super.bytesDownloaded = 0,
    super.totalBytes = 0,
    super.filePath,
  });

  DownloadInfo copyWith({
    String? url,
    String? fileName,
    String? format,
    DownloadState? state,
    DateTime? createdAt,
    int? bytesDownloaded,
    int? totalBytes,
    String? filePath,
  }) {
    return DownloadInfo(
      id: id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
    );
  }

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

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'fileName': fileName,
        'format': format,
        'state': state.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'bytesDownloaded': bytesDownloaded,
        'totalBytes': totalBytes,
        if (filePath != null) 'filePath': filePath,
      };

  @override
  List<Object?> get props => [
        id,
        url,
        fileName,
        format,
        createdAt,
        state,
        bytesDownloaded,
        totalBytes,
        filePath,
      ];
}

/// Real-time progress information for a download
class DownloadProgress extends BaseDownloadInfo {
  final double speed; // bytes per second

  const DownloadProgress({
    required super.id,
    required double progress,
    required super.bytesDownloaded,
    required super.totalBytes,
    required this.speed,
    required super.state,
    super.filePath,
  }) : super();

  String get formattedSpeed {
    if (speed < 1024) {
      return '${speed.toStringAsFixed(1)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / 1024 / 1024).toStringAsFixed(1)} MB/s';
    }
  }

  double get speedInMBps => speed / 1024 / 1024;
  double get speedInKBps => speed / 1024;

  DownloadProgress copyWith({
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    double? speed,
    DownloadState? state,
    String? filePath,
  }) {
    return DownloadProgress(
      id: id,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      speed: speed ?? this.speed,
      state: state ?? this.state,
      filePath: filePath ?? this.filePath,
    );
  }

  factory DownloadProgress.fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      id: map['id'] as String,
      progress: map['progress'] as double,
      bytesDownloaded: map['bytesDownloaded'] as int,
      totalBytes: map['totalBytes'] as int,
      speed: map['speed'] as double,
      state: DownloadState.fromJson(map['state'] as String),
      filePath: map['filePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'progress': progress,
        'bytesDownloaded': bytesDownloaded,
        'totalBytes': totalBytes,
        'speed': speed,
        'state': state.toJson(),
        if (filePath != null) 'filePath': filePath,
      };

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  @override
  List<Object?> get props => [
        id,
        progress,
        bytesDownloaded,
        totalBytes,
        speed,
        state,
        filePath,
      ];
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
