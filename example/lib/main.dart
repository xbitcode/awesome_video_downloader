import 'package:flutter/material.dart';
import 'package:awesome_video_downloader/awesome_video_downloader.dart';
import 'package:awesome_video_downloader/models/download_config.dart';
import 'package:awesome_video_downloader/models/download_task.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _downloader = AwesomeVideoDownloader();
  final List<String> _activeTaskIds = [];

  Future<void> _startDownload() async {
    final config = DownloadConfig(
      url: 'https://example.com/video.m3u8',
      title: 'Test Video',
      minimumBitrate: 2000000,
      prefersHDR: true,
    );

    final taskId = await _downloader.startDownload(config);
    if (taskId != null) {
      setState(() {
        _activeTaskIds.add(taskId);
      });

      _downloader.getDownloadProgress(taskId).listen(
        (progress) {
          print('Download progress: ${progress.progress}%');
        },
        onError: (error) {
          print('Download error: $error');
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Video Downloader Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startDownload,
                child: const Text('Start Download'),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<DownloadTask>>(
                future: _downloader.getActiveDownloads(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();

                  final downloads = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: downloads.length,
                    itemBuilder: (context, index) {
                      final task = downloads[index];
                      return ListTile(
                        title: Text(task.title),
                        subtitle: Text('Progress: ${task.progress}%'),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () =>
                              _downloader.cancelDownload(task.taskId),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
