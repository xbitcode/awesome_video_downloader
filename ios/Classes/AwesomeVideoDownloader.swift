import Foundation
import AVFoundation
import Flutter

class AwesomeVideoDownloader: NSObject, FlutterStreamHandler {
    private var downloadSession: AVAssetDownloadURLSession?
    private var activeTasks: [String: AVAssetDownloadTask] = [:]
    private var downloadLocations: [String: URL] = [:]
    private var eventSinks: [String: FlutterEventSink] = [:]
    private var playableStatusSinks: [String: FlutterEventSink] = [:]
    private var downloadProgress: [String: Double] = [:] // Track progress for each download
    
    override init() {
        super.init()
        setupDownloadSession()
    }
    
    private func setupDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.awesome_video_downloader.background")
        downloadSession = AVAssetDownloadURLSession(configuration: configuration,
                                                  assetDownloadDelegate: self,
                                                  delegateQueue: OperationQueue.main)
        restoreTasks()
    }
    
    private func restoreTasks() {
        downloadSession?.getAllTasks { tasks in
            for task in tasks {
                if let assetDownloadTask = task as? AVAssetDownloadTask,
                   let taskId = assetDownloadTask.taskDescription {
                    self.activeTasks[taskId] = assetDownloadTask
                    self.downloadProgress[taskId] = 0.0
                }
            }
        }
    }
    
    func startDownload(
        url: String,
        title: String,
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool,
        completion: @escaping (String?) -> Void
    ) {
        guard let assetURL = URL(string: url),
              let session = downloadSession else {
            completion(nil)
            return
        }
        
        let asset = AVURLAsset(url: assetURL)
        let taskId = UUID().uuidString
        
        var options: [String: Any] = [
            AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: minimumBitrate
        ]
        
        if #available(iOS 14.0, *) {
            options[AVAssetDownloadTaskPrefersHDRKey] = prefersHDR
            options["AVAssetDownloadTaskPrefersMultichannel"] = prefersMultichannel
        }
        
        guard let task = session.makeAssetDownloadTask(asset: asset,
                                                     assetTitle: title,
                                                     assetArtworkData: nil,
                                                     options: options) else {
            completion(nil)
            return
        }
        
        task.taskDescription = taskId
        activeTasks[taskId] = task
        downloadProgress[taskId] = 0.0
        task.resume()
        
        completion(taskId)
    }
    
    func pauseDownload(taskId: String) {
        activeTasks[taskId]?.suspend()
    }
    
    func resumeDownload(taskId: String) {
        activeTasks[taskId]?.resume()
    }
    
    func cancelDownload(taskId: String) {
        activeTasks[taskId]?.cancel()
        cleanupDownload(taskId)
    }
    
    private func cleanupDownload(_ taskId: String) {
        activeTasks.removeValue(forKey: taskId)
        downloadProgress.removeValue(forKey: taskId)
        eventSinks.removeValue(forKey: taskId)
        playableStatusSinks.removeValue(forKey: taskId)
    }
    
    func getActiveDownloads() -> [[String: Any]] {
        return activeTasks.map { (taskId, task) in
            return [
                "taskId": taskId,
                "url": task.urlAsset.url.absoluteString,
                "title": task.taskDescription ?? "",
                "status": task.state.rawValue,
                "progress": downloadProgress[taskId] ?? 0.0
            ]
        }
    }
    
    func isVideoPlayableOffline(taskId: String) -> Bool {
        guard let location = downloadLocations[taskId] else { return false }
        let asset = AVURLAsset(url: location)
        return asset.assetCache?.isPlayableOffline ?? false
    }
    
    func getDownloadLocation(_ taskId: String) -> URL? {
        return downloadLocations[taskId]
    }
    
    func deleteDownloadedFile(_ taskId: String) -> Bool {
        guard let location = downloadLocations[taskId] else {
            return true // File doesn't exist, consider it a success
        }
        
        do {
            try FileManager.default.removeItem(at: location)
            downloadLocations.removeValue(forKey: taskId)
            return true
        } catch {
            print("Error deleting file: \(error)")
            return false
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        if let args = arguments as? [String: Any],
           let taskId = args["taskId"] as? String {
            eventSinks[taskId] = eventSink
            
            // Send initial progress if available
            if let progress = downloadProgress[taskId] {
                eventSink([
                    "taskId": taskId,
                    "progress": progress,
                    "bytesDownloaded": activeTasks[taskId]?.countOfBytesReceived ?? 0,
                    "totalBytes": activeTasks[taskId]?.countOfBytesExpectedToReceive ?? 0
                ])
            }
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let args = arguments as? [String: Any],
           let taskId = args["taskId"] as? String {
            eventSinks.removeValue(forKey: taskId)
        }
        return nil
    }
    
    func setPlayableStatusEventSink(taskId: String, eventSink: FlutterEventSink?) {
        if let eventSink = eventSink {
            playableStatusSinks[taskId] = eventSink
            // Send initial status
            let isPlayable = isVideoPlayableOffline(taskId: taskId)
            eventSink([
                "taskId": taskId,
                "isPlayable": isPlayable
            ])
        } else {
            playableStatusSinks.removeValue(forKey: taskId)
        }
    }
}

// MARK: - AVAssetDownloadDelegate

extension AwesomeVideoDownloader: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didLoad timeRange: CMTimeRange,
                   totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                   timeRangeExpectedToLoad: CMTimeRange) {
        
        guard let taskId = assetDownloadTask.taskDescription,
              let eventSink = eventSinks[taskId] else { return }
        
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += CMTimeGetSeconds(loadedTimeRange.duration) /
                CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        }
        percentComplete *= 100
        
        // Store progress
        downloadProgress[taskId] = percentComplete
        
        eventSink([
            "taskId": taskId,
            "progress": percentComplete,
            "bytesDownloaded": assetDownloadTask.countOfBytesReceived,
            "totalBytes": assetDownloadTask.countOfBytesExpectedToReceive
        ])
    }
    
    func urlSession(_ session: URLSession,
                   assetDownloadTask: AVAssetDownloadTask,
                   didFinishDownloadingTo location: URL) {
        guard let taskId = assetDownloadTask.taskDescription else { return }
        downloadLocations[taskId] = location
        
        // Notify that the video is now playable
        if let eventSink = playableStatusSinks[taskId] {
            eventSink([
                "taskId": taskId,
                "isPlayable": true
            ])
        }
    }
    
    func urlSession(_ session: URLSession,
                   task: URLSessionTask,
                   didCompleteWithError error: Error?) {
        guard let assetDownloadTask = task as? AVAssetDownloadTask,
              let taskId = assetDownloadTask.taskDescription,
              let eventSink = eventSinks[taskId] else { return }
        
        if let error = error as NSError? {
            if error.domain == NSURLErrorDomain && error.code == -1013 {
                eventSink([
                    "taskId": taskId,
                    "error": "Authentication required for this video"
                ])
            } else if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                eventSink([
                    "taskId": taskId,
                    "status": "cancelled"
                ])
            } else {
                eventSink([
                    "taskId": taskId,
                    "error": error.localizedDescription
                ])
            }
        }
        
        cleanupDownload(taskId)
    }
}

class DownloadEventStreamHandler: NSObject, FlutterStreamHandler {
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
        return downloader.onListen(withArguments: ["taskId": taskId], eventSink: eventSink)
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let result = downloader.onCancel(withArguments: ["taskId": taskId])
        onCancel()
        return result
    }
} 