package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import com.google.android.exoplayer2.database.StandaloneDatabaseProvider
import com.google.android.exoplayer2.offline.Download
import com.google.android.exoplayer2.offline.DownloadManager
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.upstream.cache.NoOpCacheEvictor
import com.google.android.exoplayer2.upstream.cache.SimpleCache
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.offline.DownloadRequest
import io.flutter.plugin.common.EventChannel
import java.io.IOException
import java.net.HttpURLConnection

class VideoDownloadManager(private val context: Context) {
    private val eventSinks = mutableMapOf<String, EventChannel.EventSink>()
    private val downloadManager: DownloadManager
    private val activeDownloads = mutableMapOf<String, DownloadRequest>()
    private val downloadStates = mutableMapOf<String, Int>()  // Track download states

    init {
        val downloadDirectory = context.getExternalFilesDir("downloads")
        val databaseProvider = StandaloneDatabaseProvider(context)
        val downloadCache = SimpleCache(
            downloadDirectory!!,
            NoOpCacheEvictor(),
            databaseProvider
        )

        val dataSourceFactory = DefaultHttpDataSource.Factory().apply {
            setDefaultRequestProperties(mapOf(
                "User-Agent" to "AwesomeVideoDownloader"
            ))
            setConnectTimeoutMs(15000)
            setReadTimeoutMs(15000)
        }

        downloadManager = DownloadManager(
            context,
            databaseProvider,
            downloadCache,
            dataSourceFactory,
            Runnable::run
        ).apply {
            addListener(DownloadManagerListener())
        }
    }

    fun startDownload(taskId: String, url: String, title: String, auth: Map<String, String>?) {
        val mediaItem = MediaItem.fromUri(url)
        val request = DownloadRequest.Builder(taskId, mediaItem.mediaId)
            .setData(title.toByteArray())
            .setCustomCacheKey(taskId)
            .build()

        activeDownloads[taskId] = request
        downloadStates[taskId] = Download.STATE_DOWNLOADING
        downloadManager.addDownload(request)
    }

    fun pauseDownload(taskId: String) {
        downloadManager.removeDownload(taskId)
        downloadStates[taskId] = Download.STATE_STOPPED
    }

    fun resumeDownload(taskId: String) {
        activeDownloads[taskId]?.let { request ->
            downloadManager.addDownload(request)
            downloadStates[taskId] = Download.STATE_DOWNLOADING
        }
    }

    fun cancelDownload(taskId: String) {
        downloadManager.removeDownload(taskId)
        activeDownloads.remove(taskId)
        downloadStates.remove(taskId)
        eventSinks.remove(taskId)
    }

    fun setEventSink(taskId: String, eventSink: EventChannel.EventSink?) {
        if (eventSink != null) {
            eventSinks[taskId] = eventSink
        } else {
            eventSinks.remove(taskId)
        }
    }

    inner class DownloadManagerListener : DownloadManager.Listener {
        override fun onDownloadChanged(
            downloadManager: DownloadManager,
            download: Download,
            finalException: Exception?
        ) {
            val taskId = download.request.id
            val eventSink = eventSinks[taskId] ?: return
            
            // Update download state
            downloadStates[taskId] = download.state

            when {
                finalException != null -> {
                    handleDownloadError(taskId, finalException)
                    cleanupDownload(taskId)
                }
                download.state == Download.STATE_COMPLETED -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "progress" to 100.0,
                        "bytesDownloaded" to download.bytesDownloaded,
                        "totalBytes" to download.contentLength
                    ))
                    cleanupDownload(taskId)
                }
                download.state == Download.STATE_DOWNLOADING -> {
                    // Only send progress updates for active downloads
                    if (activeDownloads.containsKey(taskId)) {
                        eventSink.success(mapOf(
                            "taskId" to taskId,
                            "progress" to download.percentDownloaded,
                            "bytesDownloaded" to download.bytesDownloaded,
                            "totalBytes" to download.contentLength
                        ))
                    }
                }
                download.state == Download.STATE_FAILED -> {
                    handleDownloadError(taskId, download.failureReason)
                    cleanupDownload(taskId)
                }
            }
        }

        private fun cleanupDownload(taskId: String) {
            activeDownloads.remove(taskId)
            downloadStates.remove(taskId)
            eventSinks.remove(taskId)
        }

        private fun handleDownloadError(taskId: String, error: Exception?) {
            val eventSink = eventSinks[taskId] ?: return
            when {
                error is IOException && error.message?.contains("authentication", ignoreCase = true) == true -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "error" to "Authentication required for this video"
                    ))
                }
                error?.message?.contains("cancelled", ignoreCase = true) == true -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "status" to "cancelled"
                    ))
                }
                else -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "error" to (error?.message ?: "Unknown error")
                    ))
                }
            }
        }

        private fun handleDownloadError(taskId: String, failureReason: Int) {
            val eventSink = eventSinks[taskId] ?: return
            when (failureReason) {
                Download.FAILURE_REASON_UNKNOWN -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "error" to "Unknown error occurred"
                    ))
                }
                Download.FAILURE_REASON_IO_ERROR -> {
                    eventSink.success(mapOf(
                        "taskId" to taskId,
                        "status" to "cancelled"
                    ))
                }
                else -> {
                    eventSink?.success(mapOf(
                        "taskId" to taskId,
                        "error" to "Download failed with reason code: $failureReason"
                    ))
                }
            }
        }
    }

    fun setEventSink(eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    fun getDownloadState(taskId: String): Int {
        return downloadStates[taskId] ?: Download.STATE_STOPPED
    }

    companion object {
        @Volatile
        private var instance: VideoDownloadManager? = null

        fun getInstance(context: Context): VideoDownloadManager {
            return instance ?: synchronized(this) {
                instance ?: VideoDownloadManager(context).also { instance = it }
            }
        }
    }
} 