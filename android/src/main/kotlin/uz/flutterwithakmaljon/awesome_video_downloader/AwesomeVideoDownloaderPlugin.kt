package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.google.android.exoplayer2.offline.Download

class AwesomeVideoDownloaderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var downloadManager: VideoDownloadManager
    private lateinit var binaryMessenger: BinaryMessenger
    private val eventChannels = mutableMapOf<String, EventChannel>()
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        binaryMessenger = flutterPluginBinding.binaryMessenger
        downloadManager = VideoDownloadManager.getInstance(context)
        
        channel = MethodChannel(binaryMessenger, "awesome_video_downloader")
        channel.setMethodCallHandler(this)
    }
    
    private fun setupEventChannel(taskId: String) {
        val channelName = "awesome_video_downloader/events/$taskId"
        val eventChannel = EventChannel(binaryMessenger, channelName)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                downloadManager.setEventSink(taskId, events)
            }

            override fun onCancel(arguments: Any?) {
                downloadManager.setEventSink(taskId, null)
            }
        })
        eventChannels[taskId] = eventChannel
    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> handleStartDownload(call, result)
            "pauseDownload" -> handlePauseDownload(call, result)
            "resumeDownload" -> handleResumeDownload(call, result)
            "cancelDownload" -> handleCancelDownload(call, result)
            "getActiveDownloads" -> handleGetActiveDownloads(result)
            "isVideoPlayableOffline" -> handleIsVideoPlayableOffline(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun handleStartDownload(call: MethodCall, result: MethodChannel.Result) {
        try {
            val url = call.argument<String>("url") ?: throw IllegalArgumentException("URL is required")
            val title = call.argument<String>("title") ?: throw IllegalArgumentException("Title is required")
            val taskId = java.util.UUID.randomUUID().toString()
            
            setupEventChannel(taskId)
            downloadManager.startDownload(taskId, url, title)
            result.success(taskId)
            
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)
        }
    }
    
    private fun handlePauseDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        downloadManager.pauseDownload(taskId)
        result.success(null)
    }
    
    private fun handleResumeDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        downloadManager.resumeDownload(taskId)
        result.success(null)
    }
    
    private fun handleCancelDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        downloadManager.cancelDownload(taskId)
        eventChannels.remove(taskId)?.setStreamHandler(null)
        result.success(null)
    }
    
    private fun handleGetActiveDownloads(result: MethodChannel.Result) {
        val downloads = downloadManager.getActiveDownloads().map { download ->
            mapOf(
                "taskId" to download.request.id,
                "url" to download.request.uri.toString(),
                "title" to String(download.request.data ?: ByteArray(0)),
                "status" to download.state,
                "progress" to (download.percentDownloaded.toDouble())
            )
        }
        result.success(downloads)
    }
    
    private fun handleIsVideoPlayableOffline(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        result.success(downloadManager.isPlayableOffline(taskId))
    }
    
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannels.values.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
    }
}