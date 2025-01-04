import Flutter
import UIKit
import AVFoundation
import AVKit

public class AwesomeVideoDownloaderPlugin: NSObject, FlutterPlugin {
    private let downloader = AwesomeVideoDownloader()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "awesome_video_downloader", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "awesome_video_downloader/events", binaryMessenger: registrar.messenger())
        
        let instance = AwesomeVideoDownloaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            result(nil)
            
        case "startDownload":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String,
                  let fileName = args["fileName"] as? String,
                  let format = args["format"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Missing required arguments",
                                  details: nil))
                return
            }
            
            let options = args["options"] as? [String: Any]
            
            downloader.startDownload(
                url: url,
                fileName: fileName,
                format: format,
                options: options
            ) { downloadResult in
                switch downloadResult {
                case .success(let downloadId):
                    result(downloadId)
                case .failure(let error):
                    result(FlutterError(code: "DOWNLOAD_ERROR",
                                      message: error.localizedDescription,
                                      details: nil))
                }
            }
            
        case "pauseDownload":
            guard let args = call.arguments as? [String: Any],
                  let downloadId = args["downloadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Missing downloadId",
                                  details: nil))
                return
            }
            
            downloader.pauseDownload(downloadId: downloadId)
            result(nil)
            
        case "resumeDownload":
            guard let args = call.arguments as? [String: Any],
                  let downloadId = args["downloadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Missing downloadId",
                                  details: nil))
                return
            }
            
            downloader.resumeDownload(downloadId: downloadId)
            result(nil)
            
        case "cancelDownload":
            guard let args = call.arguments as? [String: Any],
                  let downloadId = args["downloadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Missing downloadId",
                                  details: nil))
                return
            }
            
            downloader.cancelDownload(downloadId: downloadId)
            result(nil)
            
        case "getDownloadStatus":
            guard let args = call.arguments as? [String: Any],
                  let downloadId = args["downloadId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Missing downloadId",
                                  details: nil))
                return
            }
            
            if let task = downloader.activeTasks[downloadId] {
                result([
                    "id": task.id,
                    "state": task.state,
                    "bytesDownloaded": task.bytesDownloaded,
                    "totalBytes": task.totalBytes,
                    "error": task.error as Any
                ])
            } else {
                result([:])
            }
            
        case "getAllDownloads":
            let downloads = downloader.activeTasks.values.map { task in
                return [
                    "id": task.id,
                    "url": task.url,
                    "fileName": task.fileName,
                    "format": task.format,
                    "state": task.state,
                    "bytesDownloaded": task.bytesDownloaded,
                    "totalBytes": task.totalBytes,
                    "createdAt": ISO8601DateFormatter().string(from: Date())
                ]
            }
            result(downloads)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// Add FlutterStreamHandler conformance
extension AwesomeVideoDownloaderPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        downloader.setEventSink(events)
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        downloader.setEventSink(nil)
        return nil
    }
} 