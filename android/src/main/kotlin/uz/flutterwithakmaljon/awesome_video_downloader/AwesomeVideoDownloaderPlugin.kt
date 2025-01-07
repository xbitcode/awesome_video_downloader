package uz.flutterwithakmaljon.awesome_video_downloader

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry
import android.Manifest
import android.app.Activity
import com.google.android.exoplayer2.offline.Download

class AwesomeVideoDownloaderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var activity: Activity
    private lateinit var downloadManager: VideoDownloadManager
    private lateinit var binaryMessenger: BinaryMessenger
    private val eventChannels = mutableMapOf<String, EventChannel>()
    private var pendingDownloadRequest: DownloadRequest? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private data class DownloadRequest(
        val url: String,
        val title: String,
        val result: MethodChannel.Result
    )

    companion object {
        private const val PERMISSION_REQUEST_CODE = 123
    }
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        binaryMessenger = flutterPluginBinding.binaryMessenger
        downloadManager = VideoDownloadManager.getInstance(context)
        
        channel = MethodChannel(binaryMessenger, "awesome_video_downloader")
        channel.setMethodCallHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // No implementation needed
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        // No implementation needed
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Permission granted, proceed with download
                pendingDownloadRequest?.let { request ->
                    startDownloadWithPermissionCheck(request.url, request.title, null, request.result)
                }
            } else {
                // Permission denied
                pendingDownloadRequest?.result?.error(
                    "PERMISSION_DENIED",
                    "Storage permission is required to download videos",
                    null
                )
            }
            pendingDownloadRequest = null
            return true
        }
        return false
    }

    private fun checkStoragePermission(): Boolean {
        return when {
            // For Android 11+ (API 30+), we don't need WRITE_EXTERNAL_STORAGE permission
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> true
            // For Android 10 (API 29), check if we have the permission but don't require it
            Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> true
            // For Android 9 and below, we need WRITE_EXTERNAL_STORAGE permission
            else -> ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermission() {
        // Only request permission for Android 9 (API 28) and below
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                // First time asking or user selected "Don't ask again"
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    PERMISSION_REQUEST_CODE
                )
            } else {
                // User previously denied permission, show rationale
                pendingDownloadRequest?.result?.error(
                    "PERMISSION_DENIED",
                    "Please grant storage permission in app settings to download videos",
                    null
                )
                pendingDownloadRequest = null
            }
        } else {
            // For Android 10+, proceed with download without permission
            pendingDownloadRequest?.let { request ->
                startDownloadWithPermissionCheck(request.url, request.title, null, request.result)
            }
            pendingDownloadRequest = null
        }
    }

    private fun startDownloadWithPermissionCheck(url: String, title: String, auth: Map<String, String>?, result: MethodChannel.Result) {
        if (checkStoragePermission()) {
            // Permission already granted or not needed (Android 10+), proceed with download
            val taskId = java.util.UUID.randomUUID().toString()
            println("#### Starting download - URL: $url, Title: $title, TaskId: $taskId")
            
            // Set up event channel first
            setupEventChannel(taskId)
            
            // Create a latch to wait for event sink setup
            val eventChannelLatch = java.util.concurrent.CountDownLatch(1)
            
            // Create a temporary event handler to detect when Flutter starts listening
            val channelName = "awesome_video_downloader/events/$taskId"
            val tempEventChannel = EventChannel(binaryMessenger, channelName)
            tempEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    println("#### Flutter started listening, proceeding with download")
                    downloadManager.setEventSink(taskId, events)
                    eventChannelLatch.countDown()
                }

                override fun onCancel(arguments: Any?) {
                    downloadManager.setEventSink(taskId, null)
                }
            })
            
            // Wait for Flutter to start listening (max 2 seconds)
            val success = eventChannelLatch.await(2, java.util.concurrent.TimeUnit.SECONDS)
            if (!success) {
                println("#### Warning: Timeout waiting for Flutter to start listening")
            }
            
            try {
                downloadManager.startDownload(taskId, url, title, auth)
                println("#### Download started successfully")
                result.success(taskId)
            } catch (e: Exception) {
                println("#### Download error: ${e.message}")
                e.printStackTrace()
                result.error("DOWNLOAD_ERROR", e.message ?: "Unknown error occurred", null)
            }
        } else {
            // Store the request for later
            pendingDownloadRequest = DownloadRequest(url, title, result)
            // Request permission
            requestStoragePermission()
        }
    }
    
    private fun setupEventChannel(taskId: String) {
        println("#### Starting event channel setup for taskId: $taskId")
        val channelName = "awesome_video_downloader/events/$taskId"
        println("#### Creating event channel with name: $channelName")
        val eventChannel = EventChannel(binaryMessenger, channelName)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                println("#### Flutter started listening on event channel for taskId: $taskId")
                println("#### Arguments received: $arguments")
                downloadManager.setEventSink(taskId, events)
            }

            override fun onCancel(arguments: Any?) {
                println("#### Flutter cancelled listening on event channel for taskId: $taskId")
                downloadManager.setEventSink(taskId, null)
            }
        })
        eventChannels[taskId] = eventChannel
        println("#### Event channel setup completed for taskId: $taskId")

        println("#### Setting up playable status channel for taskId: $taskId")
        val playableChannelName = "awesome_video_downloader/playable_status/$taskId"
        val playableEventChannel = EventChannel(binaryMessenger, playableChannelName)
        playableEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                println("#### Flutter started listening on playable status channel for taskId: $taskId")
                downloadManager.setPlayableStatusEventSink(taskId, events)
            }

            override fun onCancel(arguments: Any?) {
                println("#### Flutter cancelled listening on playable status channel for taskId: $taskId")
                downloadManager.setPlayableStatusEventSink(taskId, null)
            }
        })
        eventChannels["playable_$taskId"] = playableEventChannel
        println("#### Playable status channel setup completed for taskId: $taskId")
    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> {
                val url = call.argument<String>("url") ?: return result.error("INVALID_URL", "URL is required", null)
                val title = call.argument<String>("title") ?: return result.error("INVALID_TITLE", "Title is required", null)
                val auth = call.argument<Map<String, String>>("authentication")
                startDownloadWithPermissionCheck(url, title, auth, result)
            }
            "pauseDownload" -> handlePauseDownload(call, result)
            "resumeDownload" -> handleResumeDownload(call, result)
            "cancelDownload" -> handleCancelDownload(call, result)
            "getActiveDownloads" -> handleGetActiveDownloads(result)
            "isVideoPlayableOffline" -> handleIsVideoPlayableOffline(call, result)
            "getDownloadedFilePath" -> handleGetDownloadedFilePath(call, result)
            "deleteDownloadedFile" -> handleDeleteDownloadedFile(call, result)
            else -> result.notImplemented()
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
        eventChannels.remove("playable_$taskId")?.setStreamHandler(null)
        result.success(null)
    }
    
    private fun handleGetActiveDownloads(result: MethodChannel.Result) {
        val downloads = downloadManager.downloadManager.currentDownloads.map { download ->
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
    
    private fun handleGetDownloadedFilePath(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        val filePath = downloadManager.getDownloadedFilePath(taskId)
        result.success(filePath)
    }
    
    private fun handleDeleteDownloadedFile(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId") ?: return result.error("INVALID_TASK_ID", "Task ID is required", null)
        val success = downloadManager.deleteDownloadedFile(taskId)
        result.success(success)
    }
    
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannels.values.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
    }
}