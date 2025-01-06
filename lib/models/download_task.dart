enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

enum DownloadError {
  authenticationRequired,
  authenticationFailed,
  networkError,
  cancelled,
  unknown
}

class DownloadTask {
  final String taskId;
  final String url;
  final String title;
  final DownloadStatus status;
  final double progress;
  final DownloadError? errorType;
  final String? errorMessage;

  DownloadTask({
    required this.taskId,
    required this.url,
    required this.title,
    required this.status,
    this.progress = 0.0,
    this.errorType,
    this.errorMessage,
  });

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      taskId: map['taskId'],
      url: map['url'],
      title: map['title'],
      status: DownloadStatus.values[map['status']],
      progress: map['progress'],
      errorType: map['errorType'] != null
          ? DownloadError.values[map['errorType']]
          : null,
      errorMessage: map['errorMessage'],
    );
  }
}

class DownloadProgress {
  final String taskId;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final bool isCancelled;

  DownloadProgress({
    required this.taskId,
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.isCancelled = false,
  });
}
