package uz.fluttterwithakmaljon.awesome_video_downloader

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.text.SimpleDateFormat
import java.util.*

class AwesomeVideoDownloaderPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var downloader: AwesomeVideoDownloader

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "awesome_video_downloader")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "awesome_video_downloader/events")
        
        downloader = AwesomeVideoDownloader(flutterPluginBinding.applicationContext)
        
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                result.success(null)
            }
            "startDownload" -> {
                val url = call.argument<String>("url")
                val fileName = call.argument<String>("fileName")
                val format = call.argument<String>("format")
                val options = call.argument<Map<String, Any>>("options")

                if (url == null || fileName == null || format == null) {
                    result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    return
                }

                downloader.startDownload(url, fileName, format, options) { downloadResult ->
                    downloadResult.fold(
                        onSuccess = { downloadId -> result.success(downloadId) },
                        onFailure = { error ->
                            result.error(
                                "DOWNLOAD_ERROR",
                                error.message,
                                null
                            )
                        }
                    )
                }
            }
            "pauseDownload" -> {
                val downloadId = call.argument<String>("downloadId")
                if (downloadId == null) {
                    result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    return
                }
                downloader.pauseDownload(downloadId)
                result.success(null)
            }
            "resumeDownload" -> {
                val downloadId = call.argument<String>("downloadId")
                if (downloadId == null) {
                    result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    return
                }
                downloader.resumeDownload(downloadId)
                result.success(null)
            }
            "cancelDownload" -> {
                val downloadId = call.argument<String>("downloadId")
                if (downloadId == null) {
                    result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    return
                }
                downloader.cancelDownload(downloadId)
                result.success(null)
            }
            "getDownloadStatus" -> {
                val downloadId = call.argument<String>("downloadId")
                if (downloadId == null) {
                    result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    return
                }
                val task = downloader.activeTasks[downloadId]
                if (task != null) {
                    result.success(mapOf(
                        "id" to task.id,
                        "state" to task.state,
                        "bytesDownloaded" to task.bytesDownloaded,
                        "totalBytes" to task.totalBytes,
                        "error" to task.error
                    ))
                } else {
                    result.success(mapOf<String, Any>())
                }
            }
            "getAllDownloads" -> {
                val downloads = downloader.activeTasks.values.map { task ->
                    mapOf(
                        "id" to task.id,
                        "url" to task.url,
                        "fileName" to task.fileName,
                        "format" to task.format,
                        "state" to task.state,
                        "bytesDownloaded" to task.bytesDownloaded,
                        "totalBytes" to task.totalBytes,
                        "createdAt" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                            .format(Date())
                    )
                }
                result.success(downloads)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        downloader.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        downloader.setEventSink(null)
    }
} 