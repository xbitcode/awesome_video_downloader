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
            // Get current status
            _downloader.getDownloadStatus(downloadId).then((status) {
              if (mounted) {
                setState(() {
                  _downloads[index] = DownloadInfo(
                    id: downloadId,
                    url: _downloads[index].url,
                    fileName: _downloads[index].fileName,
                    format: _downloads[index].format,
                    createdAt: _downloads[index].createdAt,
                    state: status.state,
                    bytesDownloaded: _downloads[index].bytesDownloaded,
                    totalBytes: _downloads[index].totalBytes,
                    filePath: _downloads[index].filePath,
                  );
                });
              }
            });
          }
        });
      },
    );
  }

  Future<void> _startDownload() async {
    if (_urlController.text.isEmpty) return;

    final url = _urlController.text;
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;

    try {
      // Get available qualities
      final qualities = await _downloader.getAvailableQualities(url);

      if (!mounted) return;

      // Show quality selection dialog
      final selectedQuality = await showDialog<VideoQuality>(
        context: context,
        builder: (context) => QualitySelectionDialog(qualities: qualities),
      );

      if (selectedQuality == null) return;

      final downloadId = await _downloader.startDownload(
        url: url,
        fileName: fileName,
        format: _getFormat(url),
        options: VideoDownloadOptions(
          minimumBitrate: selectedQuality.bitrate,
          maximumBitrate: selectedQuality.bitrate,
          preferHDR: selectedQuality.isHDR,
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

  Widget _buildDownloadItem(DownloadInfo download) {
    return Card(
      child: ListTile(
        title: Text(download.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${download.state.name}'),
            if (download.isDownloading)
              StreamBuilder<DownloadProgress>(
                stream: _downloader.getDownloadProgress(download.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final progress = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress: ${progress.formattedProgress}'),
                      Text('Speed: ${progress.formattedSpeed}'),
                    ],
                  );
                },
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (download.isDownloading)
              TextButton(
                onPressed: () => _pauseDownload(download.id),
                child: const Text('Pause'),
              )
            else if (download.state == DownloadState.paused)
              TextButton(
                onPressed: () => _resumeDownload(download.id),
                child: const Text('Resume'),
              ),
            TextButton(
              onPressed: () => _cancelDownload(download.id),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
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
                return _buildDownloadItem(download);
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

  Future<void> _pauseDownload(String downloadId) async {
    await _downloader.pauseDownload(downloadId);
    _loadDownloads();
  }

  Future<void> _resumeDownload(String downloadId) async {
    await _downloader.resumeDownload(downloadId);
    _subscribeToProgress(downloadId);
    _loadDownloads();
  }

  Future<void> _cancelDownload(String downloadId) async {
    await _downloader.cancelDownload(downloadId);
    _progressSubscriptions[downloadId]?.cancel();
    _progressSubscriptions.remove(downloadId);
    _loadDownloads();
  }
}

class QualitySelectionDialog extends StatelessWidget {
  final List<VideoQuality> qualities;

  const QualitySelectionDialog({super.key, required this.qualities});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: qualities
            .map((q) => ListTile(
                  title: Text('${q.label} (${q.bitrateString})'),
                  subtitle: Text(q.resolution),
                  trailing: q.isHDR ? const Text('HDR') : null,
                  onTap: () => Navigator.pop(context, q),
                ))
            .toList(),
      ),
    );
  }
}
