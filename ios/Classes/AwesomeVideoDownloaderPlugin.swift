import Flutter
import UIKit
import AVFoundation

public class AwesomeVideoDownloaderPlugin: NSObject, FlutterPlugin {
    private let downloader: AwesomeVideoDownloader
    private let registrar: FlutterPluginRegistrar
    private var eventChannels: [String: FlutterEventChannel] = [:]
    
    init(downloader: AwesomeVideoDownloader = AwesomeVideoDownloader(), registrar: FlutterPluginRegistrar) {
        self.downloader = downloader
        self.registrar = registrar
        super.init()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AwesomeVideoDownloaderPlugin(registrar: registrar)
        let channel = FlutterMethodChannel(
            name: "awesome_video_downloader",
            binaryMessenger: registrar.messenger()
        )
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startDownload":
            handleStartDownload(call, result: result)
        case "pauseDownload":
            handlePauseDownload(call, result: result)
        case "resumeDownload":
            handleResumeDownload(call, result: result)
        case "cancelDownload":
            handleCancelDownload(call, result: result)
        case "getActiveDownloads":
            handleGetActiveDownloads(result: result)
        case "isVideoPlayableOffline":
            handleIsVideoPlayableOffline(call, result: result)
        case "getDownloadedFilePath":
            handleGetDownloadedFilePath(call, result: result)
        case "deleteDownloadedFile":
            handleDeleteDownloadedFile(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleStartDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let url = args["url"] as? String,
              let title = args["title"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments",
                details: nil
            ))
            return
        }
        
        let minimumBitrate = args["minimumBitrate"] as? Int ?? 2000000
        let prefersHDR = args["prefersHDR"] as? Bool ?? false
        let prefersMultichannel = args["prefersMultichannel"] as? Bool ?? false
        
        downloader.startDownload(
            url: url,
            title: title,
            minimumBitrate: minimumBitrate,
            prefersHDR: prefersHDR,
            prefersMultichannel: prefersMultichannel
        ) { taskId in
            if let taskId = taskId {
                self.setupEventChannel(for: taskId)
            }
            result(taskId)
        }
    }
    
    private func handlePauseDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(
                code: "INVALID_TASK_ID",
                message: "Task ID is required",
                details: nil
            ))
            return
        }
        
        downloader.pauseDownload(taskId: taskId)
        result(nil)
    }
    
    private func handleResumeDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(
                code: "INVALID_TASK_ID",
                message: "Task ID is required",
                details: nil
            ))
            return
        }
        
        downloader.resumeDownload(taskId: taskId)
        result(nil)
    }
    
    private func handleCancelDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(
                code: "INVALID_TASK_ID",
                message: "Task ID is required",
                details: nil
            ))
            return
        }
        
        downloader.cancelDownload(taskId: taskId)
        removeEventChannel(for: taskId)
        removeEventChannel(for: "playable_\(taskId)")
        result(nil)
    }
    
    private func removeEventChannel(for taskId: String) {
        eventChannels.removeValue(forKey: taskId)
    }
    
    private func handleGetActiveDownloads(result: @escaping FlutterResult) {
        let downloads = downloader.getActiveDownloads()
        result(downloads)
    }
    
    private func handleIsVideoPlayableOffline(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(
                code: "INVALID_TASK_ID",
                message: "Task ID is required",
                details: nil
            ))
            return
        }
        
        result(downloader.isVideoPlayableOffline(taskId: taskId))
    }
    
    private func setupEventChannel(for taskId: String) {
        let channelName = "awesome_video_downloader/events/\(taskId)"
        let eventChannel = FlutterEventChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(DownloadEventStreamHandler(
            taskId: taskId,
            downloader: downloader,
            onCancel: { [weak self] in
                self?.removeEventChannel(for: taskId)
            }
        ))
        eventChannels[taskId] = eventChannel

        // Setup playable status event channel
        let playableChannelName = "awesome_video_downloader/playable_status/\(taskId)"
        let playableEventChannel = FlutterEventChannel(
            name: playableChannelName,
            binaryMessenger: registrar.messenger()
        )
        playableEventChannel.setStreamHandler(PlayableStatusStreamHandler(
            taskId: taskId,
            downloader: downloader,
            onCancel: { [weak self] in
                self?.removeEventChannel(for: "playable_\(taskId)")
            }
        ))
        eventChannels["playable_\(taskId)"] = playableEventChannel
    }
    
    private func handleGetDownloadedFilePath(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Task ID is required", details: nil))
            return
        }
        
        if let location = downloader.getDownloadLocation(taskId) {
            result(location.path)
        } else {
            result(nil)
        }
    }
    
    private func handleDeleteDownloadedFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Task ID is required", details: nil))
            return
        }
        
        result(downloader.deleteDownloadedFile(taskId))
    }
}

class PlayableStatusStreamHandler: NSObject, FlutterStreamHandler {
    private let taskId: String
    private let downloader: AwesomeVideoDownloader
    private let onCancel: () -> Void
    
    init(taskId: String, downloader: AwesomeVideoDownloader, onCancel: @escaping () -> Void) {
        self.taskId = taskId
        self.downloader = downloader
        self.onCancel = onCancel
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        downloader.setPlayableStatusEventSink(taskId: taskId, eventSink: eventSink)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        downloader.setPlayableStatusEventSink(taskId: taskId, eventSink: nil)
        onCancel()
        return nil
    }
} 