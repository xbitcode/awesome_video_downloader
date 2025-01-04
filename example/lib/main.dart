import 'dart:async';

import 'package:flutter/material.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Downloader Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DownloaderPage(),
    );
  }
}

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final _downloader = AwesomeVideoDownloader();
  final _urlController = TextEditingController();
  final Map<String, StreamSubscription<DownloadProgress>>
      _progressSubscriptions = {};
  List<DownloadInfo> _downloads = [];

  @override
  void initState() {
    super.initState();
    _initializeDownloader();
  }

  Future<void> _initializeDownloader() async {
    try {
      await _downloader.initialize();
      _loadDownloads();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize downloader: $e')),
        );
      }
    }
  }

  Future<void> _loadDownloads() async {
    _downloads = await _downloader.getAllDownloads();
    setState(() {});

    // Subscribe to progress updates for active downloads
    for (var download in _downloads) {
      if (download.isDownloading) {
        _subscribeToProgress(download.id);
      }
    }
  }

  void _subscribeToProgress(String downloadId) {
    _progressSubscriptions[downloadId]?.cancel();
    _progressSubscriptions[downloadId] =
        _downloader.getDownloadProgress(downloadId).listen(
      (progress) {
        setState(() {
          final index = _downloads.indexWhere((d) => d.id == downloadId);
          if (index != -1) {
            _downloads[index] = _downloads[index].copyWith(
              bytesDownloaded: progress.bytesDownloaded,
              totalBytes: progress.totalBytes,
              state: progress.state,
              filePath: progress.filePath,
            );

            if (progress.isCompleted) {
              _progressSubscriptions[downloadId]?.cancel();
              _progressSubscriptions.remove(downloadId);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Download completed: ${_downloads[index].fileName}'),
                  action: progress.filePath != null
                      ? SnackBarAction(
                          label: 'Show File',
                          onPressed: () {
                            // TODO: Implement file viewing
                          },
                        )
                      : null,
                ),
              );
            }
          }
        });
      },
      onError: (error) {
        setState(() {
          final index = _downloads.indexWhere((d) => d.id == downloadId);
          if (index != -1) {
            _downloads[index] = _downloads[index].copyWith(
              state: DownloadState.failed,
            );
          }
        });
        _progressSubscriptions[downloadId]?.cancel();
        _progressSubscriptions.remove(downloadId);
      },
    );
  }

  Future<void> _startDownload() async {
    if (_urlController.text.isEmpty) return;

    final url = _urlController.text;
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    try {
      final downloadId = await _downloader.startDownload(
        url: url,
        fileName: fileName,
        format: _getFormat(url),
        options: VideoDownloadOptions(
          preferHDR: true,
          preferMultichannel: true,
        ),
      );

      _subscribeToProgress(downloadId);
      _loadDownloads();
      _urlController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start download: $e')),
        );
      }
    }
  }

  String _getFormat(String url) {
    if (url.contains('.m3u8')) return 'hls';
    if (url.contains('.mpd')) return 'dash';
    return 'mp4';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Downloader'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Enter video URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _startDownload,
                  child: const Text('Download'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _downloads.length,
              itemBuilder: (context, index) {
                final download = _downloads[index];
                return DownloadListItem(
                  download: download,
                  onPause: () async {
                    await _downloader.pauseDownload(download.id);
                    _loadDownloads();
                  },
                  onResume: () async {
                    await _downloader.resumeDownload(download.id);
                    _subscribeToProgress(download.id);
                    _loadDownloads();
                  },
                  onCancel: () async {
                    await _downloader.cancelDownload(download.id);
                    _progressSubscriptions[download.id]?.cancel();
                    _progressSubscriptions.remove(download.id);
                    _loadDownloads();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _urlController.dispose();
    super.dispose();
  }
}

class DownloadListItem extends StatelessWidget {
  final DownloadInfo download;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const DownloadListItem({
    super.key,
    required this.download,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              download.fileName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (download.isDownloading) ...[
              LinearProgressIndicator(
                value: download.progress,
              ),
              const SizedBox(height: 8),
              Text(download.formattedSize),
            ] else
              Text('Status: ${download.state.name}'),
            if (download.filePath != null)
              Text('Saved at: ${download.filePath}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (download.isDownloading)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.pause),
                    onPressed: onPause,
                  )
                else if (download.isPaused)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onResume,
                  ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.cancel),
                  onPressed: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
