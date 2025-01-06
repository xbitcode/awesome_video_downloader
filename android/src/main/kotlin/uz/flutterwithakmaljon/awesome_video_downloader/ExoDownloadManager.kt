package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import com.google.android.exoplayer2.database.StandaloneDatabaseProvider
import com.google.android.exoplayer2.offline.Download
import com.google.android.exoplayer2.offline.DownloadManager
import com.google.android.exoplayer2.offline.DownloadService
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.upstream.cache.NoOpCacheEvictor
import com.google.android.exoplayer2.upstream.cache.SimpleCache
import java.io.File
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.offline.DownloadRequest
import java.util.concurrent.ConcurrentHashMap

class ExoDownloadManager(private val context: Context) {
    private val downloadManager: DownloadManager
    private val downloadIndex: HashMap<String, Download> = HashMap()
    private val activeDownloads = ConcurrentHashMap<String, DownloadRequest>()
    
    private var progressListener: ((String, Double, Long, Long) -> Unit)? = null
    private var errorListener: ((String, String) -> Unit)? = null
    
    init {
        val downloadDirectory = File(context.getExternalFilesDir(null), "downloads")
        if (!downloadDirectory.exists()) {
            downloadDirectory.mkdirs()
        }
        
        val databaseProvider = StandaloneDatabaseProvider(context)
        val downloadCache = SimpleCache(
            downloadDirectory,
            NoOpCacheEvictor(),
            databaseProvider
        )
        
        val dataSourceFactory = DefaultHttpDataSource.Factory()
        
        downloadManager = DownloadManager(
            context,
            databaseProvider,
            downloadCache,
            dataSourceFactory,
            Runnable::run
        )
        
        downloadManager.addListener(DownloadManagerListener())
    }
    
    fun startDownload(taskId: String, url: String, title: String) {
        val mediaItem = MediaItem.fromUri(url)
        val request = DownloadRequest.Builder(taskId, mediaItem.mediaId)
            .setData(title.toByteArray())
            .setCustomCacheKey(taskId)
            .build()
            
        activeDownloads[taskId] = request
        downloadManager.addDownload(request)
    }
    
    fun pauseDownload(taskId: String) {
        downloadManager.setStopReason(taskId, Download.STOP_REASON_MANUAL)
    }
    
    fun resumeDownload(taskId: String) {
        downloadManager.setStopReason(taskId, Download.STOP_REASON_NONE)
    }
    
    fun cancelDownload(taskId: String) {
        downloadManager.removeDownload(taskId)
        activeDownloads.remove(taskId)
    }
    
    fun getActiveDownloads(): List<Download> {
        return downloadManager.currentDownloads
    }
    
    fun isPlayableOffline(taskId: String): Boolean {
        return downloadManager.downloadIndex.getDownload(taskId)?.state == Download.STATE_COMPLETED
    }
    
    fun setProgressListener(listener: (taskId: String, progress: Double, bytesDownloaded: Long, totalBytes: Long) -> Unit) {
        progressListener = listener
    }
    
    fun setErrorListener(listener: (taskId: String, error: String) -> Unit) {
        errorListener = listener
    }
    
    inner class DownloadManagerListener : DownloadManager.Listener {
        override fun onDownloadChanged(
            downloadManager: DownloadManager,
            download: Download,
            finalException: Exception?
        ) {
            downloadIndex[download.request.id] = download
            
            when (download.state) {
                Download.STATE_DOWNLOADING -> {
                    progressListener?.invoke(
                        download.request.id,
                        download.percentDownloaded.toDouble(),
                        download.bytesDownloaded,
                        download.contentLength
                    )
                }
                Download.STATE_COMPLETED -> {
                    activeDownloads.remove(download.request.id)
                    progressListener?.invoke(
                        download.request.id,
                        100.0,
                        download.bytesDownloaded,
                        download.contentLength
                    )
                }
                Download.STATE_FAILED -> {
                    activeDownloads.remove(download.request.id)
                    errorListener?.invoke(
                        download.request.id,
                        finalException?.message ?: "Download failed"
                    )
                }
            }
        }
    }
} 