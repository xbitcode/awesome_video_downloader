package uz.fluttterwithakmaljon.awesome_video_downloader

import android.content.Context
import android.net.Uri
import androidx.work.*
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.offline.*
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.upstream.cache.SimpleCache
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.*
import java.util.concurrent.TimeUnit

class AwesomeVideoDownloader(private val context: Context) {
    private var eventSink: EventChannel.EventSink? = null
    private val downloadManager: DownloadManager
    private val downloadCache: SimpleCache
    internal val activeTasks = mutableMapOf<String, DownloadTask>()
    private val workManager = WorkManager.getInstance(context)

    data class DownloadTask(
        val id: String,
        val url: String,
        val fileName: String,
        val format: String,
        var progress: Double = 0.0,
        var bytesDownloaded: Long = 0,
        var totalBytes: Long = 0,
        var state: String = "not_started",
        var error: String? = null,
        var downloadRequest: DownloadRequest? = null,
        var filePath: String? = null,
        var lastBytesDownloaded: Long = 0,
        var lastUpdateTime: Long = 0,
        var speed: Double = 0.0
    )

    init {
        val downloadDirectory = File(context.getExternalFilesDir(null), "downloads")
        if (!downloadDirectory.exists()) {
            downloadDirectory.mkdirs()
        }

        downloadCache = SimpleCache(
            downloadDirectory,
            NoOpCacheEvictor(),
            StandaloneDatabaseProvider(context)
        )

        val dataSourceFactory = DefaultHttpDataSource.Factory()
        
        downloadManager = DownloadManager(
            context,
            StandaloneDatabaseProvider(context),
            downloadCache,
            dataSourceFactory,
            Runnable::run
        ).apply {
            addListener(DownloadManagerListener())
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun startDownload(
        url: String,
        fileName: String,
        format: String,
        options: Map<String, Any>?,
        completion: (Result<String>) -> Unit
    ) {
        try {
            val downloadId = UUID.randomUUID().toString()
            val mediaItem = MediaItem.fromUri(url)
            
            val downloadRequest = DownloadRequest.Builder(downloadId, Uri.parse(url))
                .setData(fileName.toByteArray())
                .setCustomCacheKey(downloadId)
                .build()

            val task = DownloadTask(
                id = downloadId,
                url = url,
                fileName = fileName,
                format = format,
                state = "downloading",
                downloadRequest = downloadRequest
            )
            activeTasks[downloadId] = task

            // Create WorkManager request for background download
            val downloadWorkRequest = OneTimeWorkRequestBuilder<DownloadWorker>()
                .setInputData(workDataOf(
                    "downloadId" to downloadId,
                    "url" to url,
                    "fileName" to fileName
                ))
                .setBackoffCriteria(
                    BackoffPolicy.LINEAR,
                    OneTimeWorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()

            workManager.enqueue(downloadWorkRequest)
            downloadManager.addDownload(downloadRequest)
            
            completion(Result.success(downloadId))
        } catch (e: Exception) {
            Log.e("AwesomeVideoDownloader", "Error starting download", e)
            completion(Result.failure(e))
        }
    }

    fun pauseDownload(downloadId: String) {
        activeTasks[downloadId]?.let { task ->
            task.downloadRequest?.let { request ->
                downloadManager.removeDownload(request.id)
                task.state = "paused"
                notifyTaskUpdate(task)
            }
        }
    }

    fun resumeDownload(downloadId: String) {
        activeTasks[downloadId]?.let { task ->
            task.downloadRequest?.let { request ->
                downloadManager.addDownload(request)
                task.state = "downloading"
                notifyTaskUpdate(task)
            }
        }
    }

    fun cancelDownload(downloadId: String) {
        activeTasks[downloadId]?.let { task ->
            task.downloadRequest?.let { request ->
                downloadManager.removeDownload(request.id)
                activeTasks.remove(downloadId)
                notifyTaskUpdate(task.copy(state = "cancelled"))
            }
        }
    }

    fun getAvailableQualities(url: String, result: Result) {
        val mediaItem = MediaItem.fromUri(url)
        val qualities = mutableListOf<Map<String, Any>>()
        
        val dataSourceFactory = DefaultHttpDataSource.Factory()
        val mediaSource = when {
            url.endsWith(".m3u8") -> HlsMediaSource.Factory(dataSourceFactory)
            url.endsWith(".mpd") -> DashMediaSource.Factory(dataSourceFactory)
            else -> ProgressiveMediaSource.Factory(dataSourceFactory)
        }.createMediaSource(mediaItem)

        mediaSource.addEventListener(Handler(Looper.getMainLooper()), object : MediaSourceEventListener {
            override fun onLoadCompleted(
                windowIndex: Int,
                mediaPeriodId: MediaSource.MediaPeriodId?,
                loadEventInfo: LoadEventInfo,
                mediaLoadData: MediaLoadData
            ) {
                val format = mediaLoadData.trackFormat
                if (format != null && format.height > 0) {
                    qualities.add(mapOf(
                        "id" to format.id.toString(),
                        "width" to format.width,
                        "height" to format.height,
                        "bitrate" to format.bitrate,
                        "codec" to format.codecs ?: "h264",
                        "isHDR" to (format.colorInfo?.colorTransfer == C.COLOR_TRANSFER_HLG),
                        "label" to "${format.height}p"
                    ))
                }
            }
        })

        result.success(qualities)
    }

    private inner class DownloadManagerListener : DownloadManager.Listener {
        override fun onDownloadChanged(
            downloadManager: DownloadManager,
            download: Download,
            finalException: Exception?
        ) {
            val task = activeTasks[download.request.id] ?: return

            when (download.state) {
                Download.STATE_COMPLETED -> {
                    task.state = "completed"
                    task.progress = 1.0
                    val downloadedFile = File(context.getExternalFilesDir(null), "downloads/${task.fileName}")
                    if (downloadedFile.exists()) {
                        task.filePath = downloadedFile.absolutePath
                    }
                    notifyTaskUpdate(task)
                    eventSink?.endOfStream()
                }
                Download.STATE_FAILED -> {
                    task.state = "failed"
                    task.error = finalException?.message
                }
                Download.STATE_DOWNLOADING -> {
                    task.state = "downloading"
                    task.progress = download.percentDownloaded / 100.0
                    task.bytesDownloaded = download.bytesDownloaded
                    task.totalBytes = download.contentLength

                    // Calculate speed
                    val currentTime = System.currentTimeMillis()
                    if (task.lastUpdateTime > 0) {
                        val timeDiff = (currentTime - task.lastUpdateTime) / 1000.0 // seconds
                        if (timeDiff > 0) {
                            val bytesDiff = task.bytesDownloaded - task.lastBytesDownloaded
                            task.speed = bytesDiff / timeDiff // bytes per second
                        }
                    }

                    task.lastBytesDownloaded = task.bytesDownloaded
                    task.lastUpdateTime = currentTime
                }
                Download.STATE_STOPPED -> {
                    task.state = "paused"
                }
            }

            notifyTaskUpdate(task)
        }
    }

    private fun notifyTaskUpdate(task: DownloadTask) {
        val progressMap = mutableMapOf(
            "id" to task.id,
            "progress" to task.progress,
            "bytesDownloaded" to task.bytesDownloaded,
            "totalBytes" to task.totalBytes,
            "speed" to task.speed,
            "state" to task.state
        )
        
        task.filePath?.let { path ->
            progressMap["filePath"] = path
        }
        
        eventSink?.success(progressMap)
    }
} 