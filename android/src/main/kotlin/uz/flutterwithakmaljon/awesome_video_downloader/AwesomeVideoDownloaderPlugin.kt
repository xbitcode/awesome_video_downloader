package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.Downloader
import androidx.media3.exoplayer.hls.offline.HlsDownloader
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs

private const val TAG = "AwesomeVideoDownloader"
private const val PROGRESS_THRESHOLD = 0.01f // 0.1% threshold
private const val MIN_UPDATE_INTERVAL = 100L // 100ms

enum class DownloadState(val value: String) {
    INITIAL("initial"),
    DOWNLOADING("downloading"),
    PAUSED("paused"),
    COMPLETED("completed"),
    FAILED("failed");

    override fun toString(): String = value
}

class AwesomeVideoDownloaderPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var binaryMessenger: BinaryMessenger
    private val downloadTasks = mutableMapOf<String, Downloader>()
    private val progressChannels = mutableMapOf<String, EventChannel>()
    private val progressSinks = mutableMapOf<String, EventChannel.EventSink>()
    private val lastProgressUpdates = mutableMapOf<String, Float>()
    private val lastUpdateTimes = mutableMapOf<String, Long>()
    private val downloadStates = mutableMapOf<String, DownloadState>()
    private lateinit var downloadCache: Cache
    private val mainHandler = Handler(Looper.getMainLooper())
    private val taskCounter = AtomicInteger(0)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        binaryMessenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(binaryMessenger, "awesome_video_downloader")
        channel.setMethodCallHandler(this)

        try {
            val cacheDir = File(context.cacheDir, "media_downloads")
            downloadCache = SimpleCache(cacheDir, NoOpCacheEvictor())
            Log.d(TAG, "Cache initialized at ${cacheDir.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing cache", e)
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startDownload" -> handleStartDownload(call, result)
            "pauseDownload" -> handlePauseDownload(call, result)
            "resumeDownload" -> handleResumeDownload(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartDownload(call: MethodCall, result: Result) {
        try {
            val url = call.argument<String>("url") ?: throw IllegalArgumentException("URL is required")
            val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
            val taskId = generateTaskId()

            Log.d(TAG, "Starting download for URL: $url")

            val mediaItem = MediaItem.Builder()
                .setUri(url)
                .setMimeType(detectMimeType(url))
                .build()

            val httpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setDefaultRequestProperties(headers)
                .setConnectTimeoutMs(30000)
                .setReadTimeoutMs(30000)
                .setAllowCrossProtocolRedirects(true)
            
            val cacheDataSourceFactory = CacheDataSource.Factory()
                .setCache(downloadCache)
                .setUpstreamDataSourceFactory(httpDataSourceFactory)
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

            val downloader = createDownloader(mediaItem, cacheDataSourceFactory, url)
            downloadTasks[taskId] = downloader

            setupProgressTracking(taskId)
            lastProgressUpdates[taskId] = 0f
            lastUpdateTimes[taskId] = 0L
            downloadStates[taskId] = DownloadState.INITIAL

            Executors.newSingleThreadExecutor().execute {
                try {
                    var lastContentLength = 0L
                    Log.d(TAG, "Download started for taskId: $taskId")
                    downloadStates[taskId] = DownloadState.DOWNLOADING
                    
                    downloader.download { contentLength, bytesDownloaded, percentDownloaded ->
                        lastContentLength = contentLength
                        val currentTime = System.currentTimeMillis()
                        
                        if (shouldSendProgressUpdate(taskId, percentDownloaded, currentTime)) {
                            mainHandler.post {
                                progressSinks[taskId]?.success(mapOf(
                                    "taskId" to taskId,
                                    "progress" to percentDownloaded.toDouble(),
                                    "bytesDownloaded" to bytesDownloaded,
                                    "totalBytes" to contentLength,
                                    "status" to downloadStates[taskId]?.value
                                ))
                            }
                            lastProgressUpdates[taskId] = percentDownloaded
                            lastUpdateTimes[taskId] = currentTime
                        }
                    }
                    
                    downloadStates[taskId] = DownloadState.COMPLETED
                    mainHandler.post {
                        progressSinks[taskId]?.success(mapOf(
                            "taskId" to taskId,
                            "progress" to 100.0,
                            "bytesDownloaded" to lastContentLength,
                            "totalBytes" to lastContentLength,
                            "status" to DownloadState.COMPLETED.value
                        ))
                    }
                } catch (e: Exception) {
                    downloadStates[taskId] = DownloadState.FAILED
                    Log.e(TAG, "Download failed for taskId: $taskId", e)
                    mainHandler.post {
                        progressSinks[taskId]?.error(
                            "DOWNLOAD_ERROR",
                            "Download failed: ${e.message}",
                            null
                        )
                    }
                }
            }
            result.success(taskId)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting download", e)
            result.error("START_DOWNLOAD_ERROR", e.message, null)
        }
    }

    private fun shouldSendProgressUpdate(taskId: String, currentProgress: Float, currentTime: Long): Boolean {
        val lastProgress = lastProgressUpdates[taskId] ?: 0f
        val lastUpdateTime = lastUpdateTimes[taskId] ?: 0L
        
        // Always send first update (0%) and last update (100%)
        if (lastProgress == 0f || currentProgress >= 100f) {
            return true
        }

        val progressDiff = abs(currentProgress - lastProgress)
        val timeDiff = currentTime - lastUpdateTime

        return progressDiff >= PROGRESS_THRESHOLD && timeDiff >= MIN_UPDATE_INTERVAL
    }

    private fun detectMimeType(url: String): String {
        return when {
            url.endsWith(".m3u8", ignoreCase = true) -> MimeTypes.APPLICATION_M3U8
            url.contains(".m3u8", ignoreCase = true) -> MimeTypes.APPLICATION_M3U8
            else -> MimeTypes.VIDEO_MP4
        }
    }

    private fun createDownloader(
        mediaItem: MediaItem,
        cacheDataSourceFactory: CacheDataSource.Factory,
        url: String
    ): Downloader {
        return when (detectMimeType(url)) {
            MimeTypes.APPLICATION_M3U8 -> HlsDownloader(mediaItem, cacheDataSourceFactory)
            else -> ProgressiveDownloader(mediaItem, cacheDataSourceFactory)
        }
    }

    private fun setupProgressTracking(taskId: String) {
        val eventChannel = EventChannel(binaryMessenger, "awesome_video_downloader/events/$taskId")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                progressSinks[taskId] = events
            }

            override fun onCancel(arguments: Any?) {
                progressSinks.remove(taskId)
            }
        })
        progressChannels[taskId] = eventChannel
    }

    private fun generateTaskId(): String {
        val counter = taskCounter.getAndIncrement()
        val uuid = UUID.randomUUID().toString().substring(0, 8) // Take first 8 chars of UUID
        return "task_${uuid}_$counter"
    }

    private fun handlePauseDownload(call: MethodCall, result: Result) {
        try {
            val taskId = call.argument<String>("taskId") 
                ?: throw IllegalArgumentException("Task ID is required")

            Log.d(TAG, "Pausing download for taskId: $taskId")
            
            val downloader = downloadTasks[taskId] 
                ?: throw IllegalStateException("No download task found for ID: $taskId")

            Executors.newSingleThreadExecutor().execute {
                try {
                    downloader.cancel()
                    downloadStates[taskId] = DownloadState.PAUSED
                    
                    mainHandler.post {
                        progressSinks[taskId]?.success(mapOf(
                            "taskId" to taskId,
                            "status" to DownloadState.PAUSED.value,
                            "progress" to (lastProgressUpdates[taskId] ?: 0f).toDouble()
                        ))
                        result.success(null)
                    }
                } catch (e: Exception) {
                    mainHandler.post {
                        Log.e(TAG, "Error pausing download: $taskId", e)
                        result.error(
                            "PAUSE_ERROR",
                            "Failed to pause download: ${e.message}",
                            null
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling pause request", e)
            result.error("PAUSE_ERROR", e.message, null)
        }
    }

    private fun handleResumeDownload(call: MethodCall, result: Result) {
        try {
            val taskId = call.argument<String>("taskId") 
                ?: throw IllegalArgumentException("Task ID is required")

            Log.d(TAG, "Resuming download for taskId: $taskId")
            
            val downloader = downloadTasks[taskId] 
                ?: throw IllegalStateException("No download task found for ID: $taskId")

            if (downloadStates[taskId] == DownloadState.DOWNLOADING) {
                result.success(null) // Already running
                return
            }

            Executors.newSingleThreadExecutor().execute {
                try {
                    var lastContentLength = 0L
                    downloadStates[taskId] = DownloadState.DOWNLOADING

                    downloader.download { contentLength, bytesDownloaded, percentDownloaded ->
                        lastContentLength = contentLength
                        val currentTime = System.currentTimeMillis()
                        
                        if (shouldSendProgressUpdate(taskId, percentDownloaded, currentTime)) {
                            mainHandler.post {
                                progressSinks[taskId]?.success(mapOf(
                                    "taskId" to taskId,
                                    "progress" to percentDownloaded.toDouble(),
                                    "bytesDownloaded" to bytesDownloaded,
                                    "totalBytes" to contentLength,
                                    "status" to downloadStates[taskId]?.value
                                ))
                            }
                            lastProgressUpdates[taskId] = percentDownloaded
                            lastUpdateTimes[taskId] = currentTime
                        }
                    }

                    downloadStates[taskId] = DownloadState.COMPLETED
                    mainHandler.post {
                        progressSinks[taskId]?.success(mapOf(
                            "taskId" to taskId,
                            "progress" to 100.0,
                            "bytesDownloaded" to lastContentLength,
                            "totalBytes" to lastContentLength,
                            "status" to DownloadState.COMPLETED.value
                        ))
                    }
                } catch (e: Exception) {
                    if (downloadStates[taskId] == DownloadState.PAUSED) {
                        // Download was paused, not an error
                        return@execute
                    }
                    downloadStates[taskId] = DownloadState.FAILED
                    mainHandler.post {
                        Log.e(TAG, "Error resuming download: $taskId", e)
                        progressSinks[taskId]?.error(
                            "DOWNLOAD_ERROR",
                            "Download failed: ${e.message}",
                            null
                        )
                        result.error(
                            "RESUME_ERROR",
                            "Failed to resume download: ${e.message}",
                            null
                        )
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling resume request", e)
            result.error("RESUME_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        progressChannels.clear()
        progressSinks.clear()
        downloadTasks.clear()
        downloadStates.clear()
        downloadCache.release()
    }

    private class ProgressiveDownloader(
        mediaItem: MediaItem,
        cacheDataSourceFactory: CacheDataSource.Factory
    ) : Downloader {
        private val downloader = androidx.media3.exoplayer.offline.ProgressiveDownloader(
            mediaItem,
            cacheDataSourceFactory
        )

        override fun download(progressListener: Downloader.ProgressListener?) {
            downloader.download(progressListener)
        }

        override fun cancel() {
            downloader.cancel()
        }

        override fun remove() {
            downloader.remove()
        }
    }
} 