package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import android.net.Uri
import com.google.android.exoplayer2.database.StandaloneDatabaseProvider
import com.google.android.exoplayer2.offline.Download
import com.google.android.exoplayer2.offline.DownloadManager
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.upstream.cache.NoOpCacheEvictor
import com.google.android.exoplayer2.upstream.cache.SimpleCache
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.offline.DownloadRequest
import com.google.android.exoplayer2.offline.DownloadService
import com.google.android.exoplayer2.source.hls.offline.HlsDownloader
import com.google.android.exoplayer2.source.hls.playlist.HlsPlaylistParser
import com.google.android.exoplayer2.upstream.ParsingLoadable
import io.flutter.plugin.common.EventChannel
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.io.File
import java.io.FileOutputStream

class VideoDownloadManager(private val context: Context) {
    private val eventSinks = mutableMapOf<String, EventChannel.EventSink>()
    private val playableStatusSinks = mutableMapOf<String, EventChannel.EventSink>()
    val downloadManager: DownloadManager
    private val activeDownloads = mutableMapOf<String, DownloadRequest>()
    private val downloadStates = mutableMapOf<String, Int>()
    private val pendingEvents = mutableMapOf<String, MutableList<Map<String, Any>>>()
    private val dataSourceFactory: DefaultHttpDataSource.Factory

    init {
        // Use app-specific directory for downloads
        val downloadDirectory = context.getExternalFilesDir(null)?.also { dir ->
            dir.mkdirs()
            File(dir, "downloads").also { it.mkdirs() }
        } ?: throw IllegalStateException("Cannot access external storage")
        
        println("#### Download directory: ${downloadDirectory.absolutePath}")
        
        val databaseProvider = StandaloneDatabaseProvider(context)
        val downloadCache = SimpleCache(
            File(downloadDirectory, "downloads"),
            NoOpCacheEvictor(),
            databaseProvider
        )

        dataSourceFactory = DefaultHttpDataSource.Factory().apply {
            setDefaultRequestProperties(mapOf(
                "User-Agent" to "AwesomeVideoDownloader"
            ))
            setConnectTimeoutMs(30000)
            setReadTimeoutMs(30000)
            setAllowCrossProtocolRedirects(true)
        }

        downloadManager = DownloadManager(
            context,
            databaseProvider,
            downloadCache,
            dataSourceFactory,
            Runnable::run
        ).apply {
            maxParallelDownloads = 1
            minRetryCount = 10
            addListener(DownloadManagerListener())
        }
        
        // Clean up any incomplete downloads
        downloadManager.downloadIndex.getDownloads().use { cursor ->
            while (cursor.moveToNext()) {
                val download = cursor.download
                if (download.state != Download.STATE_COMPLETED) {
                    downloadManager.removeDownload(download.request.id)
                }
            }
        }
    }

    fun startDownload(taskId: String, url: String, title: String, auth: Map<String, String>?) {
        println("#### VideoDownloadManager - Starting download for taskId: $taskId")
        println("#### URL: $url")
        
        try {
            // Configure authentication if provided
            if (auth != null) {
                when (auth["type"]) {
                    "basic" -> {
                        val username = auth["username"]
                        val password = auth["password"]
                        if (username != null && password != null) {
                            dataSourceFactory.setDefaultRequestProperties(mapOf(
                                "Authorization" to "Basic ${android.util.Base64.encodeToString(
                                    "$username:$password".toByteArray(),
                                    android.util.Base64.NO_WRAP
                                )}"
                            ))
                        }
                    }
                    "bearer" -> {
                        val token = auth["token"]
                        if (token != null) {
                            dataSourceFactory.setDefaultRequestProperties(mapOf(
                                "Authorization" to "Bearer $token"
                            ))
                        }
                    }
                    else -> {
                        // Custom headers
                        auth.forEach { (key, value) ->
                            dataSourceFactory.setDefaultRequestProperties(mapOf(key to value))
                        }
                    }
                }
            }

            val uri = Uri.parse(url)
            println("#### URI parsed: $uri")
            
            if (url.contains(".m3u8")) {
                // For HLS streams
                Thread {
                    try {
                        val mediaItem = MediaItem.Builder()
                            .setUri(uri)
                            .setMediaId(taskId)
                            .setMimeType("application/x-mpegURL")
                            .build()
                        
                        val request = DownloadRequest.Builder(taskId, uri)
                            .setData(title.toByteArray())
                            .setMimeType("application/x-mpegURL")
                            .setStreamKeys(null)
                            .build()
                        
                        activeDownloads[taskId] = request
                        downloadStates[taskId] = Download.STATE_DOWNLOADING

                        // Wait for event sink to be set up
                        var attempts = 0
                        while (eventSinks[taskId] == null && attempts < 10) {
                            println("#### Waiting for event sink to be set up... Attempt ${attempts + 1}")
                            Thread.sleep(100)
                            attempts++
                        }

                        if (eventSinks[taskId] == null) {
                            println("#### Warning: Event sink not set up after waiting")
                        } else {
                            println("#### Event sink is ready for taskId: $taskId")
                        }
                        
                        try {
                            // Always try background download first
                            downloadManager.addDownload(request)
                            println("#### HLS download added directly to manager")
                            
                            // Then start foreground service
                            DownloadService.start(
                                context,
                                VideoDownloadService::class.java
                            )
                            println("#### Download service started")
                            
                        } catch (e: Exception) {
                            println("#### Error in download process: ${e.message}")
                            e.printStackTrace()
                            eventSinks[taskId]?.success(mapOf(
                                "taskId" to taskId,
                                "error" to when {
                                    e.message?.contains("401") == true -> "Authentication required"
                                    e.message?.contains("403") == true -> "Authentication failed"
                                    else -> (e.message ?: "Download process failed")
                                }
                            ))
                        }
                        
                    } catch (e: Exception) {
                        println("#### Error starting HLS download: ${e.message}")
                        e.printStackTrace()
                        eventSinks[taskId]?.success(mapOf(
                            "taskId" to taskId,
                            "error" to when {
                                e.message?.contains("401") == true -> "Authentication required"
                                e.message?.contains("403") == true -> "Authentication failed"
                                else -> (e.message ?: "Failed to start HLS download")
                            }
                        ))
                    }
                }.start()
            } else {
                // For non-HLS streams
                val mediaItem = MediaItem.Builder()
                    .setUri(uri)
                    .setMediaId(taskId)
                    .build()
                
                val request = DownloadRequest.Builder(taskId, uri)
                    .setData(title.toByteArray())
                    .setCustomCacheKey(taskId)
                    .build()
                
                activeDownloads[taskId] = request
                downloadStates[taskId] = Download.STATE_DOWNLOADING
                
                try {
                    // Try to start as foreground service first
                    DownloadService.sendAddDownload(
                        context,
                        VideoDownloadService::class.java,
                        request,
                        /* foreground= */ true
                    )
                    println("#### Regular download request sent to foreground service")
                } catch (e: Exception) {
                    println("#### Failed to start foreground service: ${e.message}")
                    // Fall back to background download
                    downloadManager.addDownload(request)
                    println("#### Regular download added directly to manager")
                }
            }
            
        } catch (e: Exception) {
            println("#### Error starting download: ${e.message}")
            e.printStackTrace()
            eventSinks[taskId]?.success(mapOf(
                "taskId" to taskId,
                "error" to when {
                    e.message?.contains("401") == true -> "Authentication required"
                    e.message?.contains("403") == true -> "Authentication failed"
                    else -> (e.message ?: "Unknown error occurred")
                }
            ))
        }
    }

    inner class DownloadManagerListener : DownloadManager.Listener {
        private var lastProgress = -1.0f

        override fun onDownloadChanged(downloadManager: DownloadManager, download: Download, finalException: Exception?) {
            println("#### Download changed - TaskId: ${download.request.id}, State: ${download.state}")
            println("#### Download progress: ${download.percentDownloaded}%")
            println("#### Bytes downloaded: ${download.bytesDownloaded} / ${download.contentLength}")
            
            val taskId = download.request.id
            downloadStates[taskId] = download.state

            val eventSink = eventSinks[taskId]
            println("#### Event sink for taskId $taskId is ${if (eventSink == null) "NOT SET" else "SET"}")

            // Always send progress updates when downloading
            val currentProgress = download.percentDownloaded.toFloat()
            if (eventSink != null && (currentProgress != lastProgress || download.state == Download.STATE_COMPLETED)) {
                lastProgress = currentProgress
                val event = mapOf(
                    "taskId" to taskId,
                    "progress" to currentProgress.toDouble(),
                    "bytesDownloaded" to download.bytesDownloaded,
                    "totalBytes" to download.contentLength
                )
                println("#### Sending progress event: $event")
                try {
                    eventSink.success(event)
                    println("#### Successfully sent progress event to Flutter for taskId: $taskId")
                } catch (e: Exception) {
                    println("#### Error sending progress event to Flutter: ${e.message}")
                    e.printStackTrace()
                }
            }

            when (download.state) {
                Download.STATE_COMPLETED -> {
                    println("#### Download completed for taskId: $taskId")
                    val playableEvent = mapOf(
                        "taskId" to taskId,
                        "isPlayable" to true
                    )
                    playableStatusSinks[taskId]?.success(playableEvent)
                }
                Download.STATE_FAILED -> {
                    println("#### Download failed for taskId: $taskId - ${finalException?.message}")
                    eventSink?.success(mapOf(
                        "taskId" to taskId,
                        "error" to (finalException?.message ?: "Download failed")
                    ))
                }
                else -> {
                    println("#### Download state changed for taskId: $taskId - State: ${download.state}")
                }
            }
        }
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
        println("#### Setting event sink for taskId: $taskId")
        if (eventSink != null) {
            eventSinks[taskId] = eventSink
            // Send any pending events
            pendingEvents[taskId]?.let { events ->
                events.forEach { event ->
                    sendEventOnMainThread(taskId, event)
                }
                pendingEvents.remove(taskId)
            }
        } else {
            eventSinks.remove(taskId)
        }
    }

    private fun sendEventOnMainThread(taskId: String, event: Map<String, Any>) {
        val eventSink = eventSinks[taskId]
        if (eventSink != null) {
            println("#### Attempting to send event for taskId: $taskId - $event")
            try {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    try {
                        eventSink.success(event)
                        println("#### Successfully sent event to Flutter for taskId: $taskId")
                    } catch (e: Exception) {
                        println("#### Error sending event to Flutter: ${e.message}")
                        e.printStackTrace()
                    }
                }
            } catch (e: Exception) {
                println("#### Error posting to main handler: ${e.message}")
                e.printStackTrace()
            }
        } else {
            println("#### No event sink found for taskId: $taskId, queueing event")
            pendingEvents.getOrPut(taskId) { mutableListOf() }.add(event)
            println("#### Event queued. Total pending events for taskId: ${pendingEvents[taskId]?.size}")
        }
    }

    fun isPlayableOffline(taskId: String): Boolean {
        val download = downloadManager.downloadIndex.getDownload(taskId)
        return download?.state == Download.STATE_COMPLETED
    }

    fun getDownloadedFilePath(taskId: String): String? {
        val download = downloadManager.downloadIndex.getDownload(taskId) ?: return null
        if (download.state != Download.STATE_COMPLETED) return null
        
        val cacheDir = context.getExternalFilesDir(null)?.absolutePath ?: return null
        return "$cacheDir/downloads/$taskId"
    }

    fun deleteDownloadedFile(taskId: String): Boolean {
        return try {
            downloadManager.removeDownload(taskId)
            val filePath = getDownloadedFilePath(taskId)
            if (filePath != null) {
                File(filePath).delete()
            }
            true
        } catch (e: Exception) {
            println("#### Error deleting download: ${e.message}")
            false
        }
    }

    fun setPlayableStatusEventSink(taskId: String, eventSink: EventChannel.EventSink?) {
        println("#### Setting playable status event sink for taskId: $taskId")
        if (eventSink != null) {
            playableStatusSinks[taskId] = eventSink
        } else {
            playableStatusSinks.remove(taskId)
        }
    }

    companion object {
        @Volatile
        private var instance: VideoDownloadManager? = null

        fun getInstance(context: Context): VideoDownloadManager {
            return instance ?: synchronized(this) {
                instance ?: VideoDownloadManager(context.applicationContext).also { instance = it }
            }
        }
    }
} 