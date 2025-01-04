import Foundation
import AVFoundation
import AVKit
import Flutter

class AwesomeVideoDownloader: NSObject, AVAssetDownloadDelegate {
    private var eventSink: FlutterEventSink?
    private var downloadSession: AVAssetDownloadURLSession?
    internal var activeTasks: [String: DownloadTask] = [:]
    
    class DownloadTask {
        let id: String
        let url: String
        let fileName: String
        let format: String
        var assetDownloadTask: AVAssetDownloadTask?
        var progress: Double = 0
        var bytesDownloaded: Int64 = 0
        var totalBytes: Int64 = 0
        var state: String = "not_started"
        var error: String?
        var filePath: String?
        var lastBytesDownloaded: Int64 = 0
        var lastUpdateTime: Date?
        var speed: Double = 0.0
        
        init(id: String, url: String, fileName: String, format: String) {
            self.id = id
            self.url = url
            self.fileName = fileName
            self.format = format
        }
    }
    
    private let AVAssetDownloadTaskPrefersMultichannelKey = "AVAssetDownloadTaskPrefersMultichannel"
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.awesome_video_downloader")
        downloadSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
    }
    
    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    func startDownload(
        url: String,
        fileName: String,
        format: String,
        options: [String: Any]?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let assetURL = URL(string: url) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let asset = AVURLAsset(url: assetURL)
        var downloadOptions: [String: Any] = [:]
        
        if let opts = options {
            if let minBitrate = opts["minimumBitrate"] as? Int {
                downloadOptions[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = minBitrate
            }
            if let preferHDR = opts["preferHDR"] as? Bool, preferHDR {
                if #available(iOS 14.0, *) {
                    downloadOptions["AVAssetDownloadTaskPrefersHDR"] = true
                }
            }
            if let preferMultichannel = opts["preferMultichannel"] as? Bool, preferMultichannel {
                downloadOptions[AVAssetDownloadTaskPrefersMultichannelKey] = true
            }
        }
        
        guard let downloadTask = downloadSession?.makeAssetDownloadTask(
            asset: asset,
            assetTitle: fileName,
            assetArtworkData: nil,
            options: downloadOptions
        ) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create download task"])))
            return
        }
        
        let taskId = UUID().uuidString
        let task = DownloadTask(id: taskId, url: url, fileName: fileName, format: format)
        task.assetDownloadTask = downloadTask
        task.state = "downloading"
        activeTasks[taskId] = task
        
        downloadTask.resume()
        completion(.success(taskId))
    }
    
    func pauseDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else { return }
        task.assetDownloadTask?.suspend()
        task.state = "paused"
        notifyTaskUpdate(task)
    }
    
    func resumeDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else { return }
        task.assetDownloadTask?.resume()
        task.state = "downloading"
        notifyTaskUpdate(task)
    }
    
    func cancelDownload(downloadId: String) {
        guard let task = activeTasks[downloadId] else { return }
        task.assetDownloadTask?.cancel()
        activeTasks.removeValue(forKey: downloadId)
    }
    
    // MARK: - AVAssetDownloadDelegate
    
    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        guard let taskId = getTaskId(for: assetDownloadTask) else { return }
        guard let task = activeTasks[taskId] else { return }
        
        // Calculate progress
        let totalDuration = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        var loadedDuration: Double = 0
        for rangeValue in loadedTimeRanges {
            let timeRange = rangeValue.timeRangeValue
            loadedDuration += CMTimeGetSeconds(timeRange.duration)
        }
        
        task.progress = totalDuration > 0 ? loadedDuration / totalDuration : 0
        
        // Calculate speed
        let currentTime = Date()
        if let lastTime = task.lastUpdateTime {
            let timeDiff = currentTime.timeIntervalSince(lastTime)
            if timeDiff > 0 {
                let bytesDiff = task.bytesDownloaded - task.lastBytesDownloaded
                task.speed = Double(bytesDiff) / timeDiff  // bytes per second
            }
        }
        
        task.lastBytesDownloaded = task.bytesDownloaded
        task.lastUpdateTime = currentTime
        
        notifyTaskUpdate(task)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? AVAssetDownloadTask,
              let taskId = getTaskId(for: downloadTask) else { return }
        
        if let error = error {
            activeTasks[taskId]?.state = "failed"
            activeTasks[taskId]?.error = error.localizedDescription
        } else {
            activeTasks[taskId]?.state = "completed"
        }
        
        if let task = activeTasks[taskId] {
            notifyTaskUpdate(task)
        }
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = getTaskId(for: assetDownloadTask) else { return }
        
        activeTasks[taskId]?.filePath = location.path
        activeTasks[taskId]?.state = "completed"
        activeTasks[taskId]?.progress = 1.0
        
        if let task = activeTasks[taskId] {
            notifyTaskUpdate(task)
            eventSink?(FlutterEndOfEventStream)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTaskId(for downloadTask: AVAssetDownloadTask) -> String? {
        return activeTasks.first { $0.value.assetDownloadTask === downloadTask }?.key
    }
    
    private func notifyTaskUpdate(_ task: DownloadTask) {
        var progressMap: [String: Any] = [
            "id": task.id,
            "progress": task.progress,
            "bytesDownloaded": task.bytesDownloaded,
            "totalBytes": task.totalBytes,
            "speed": task.speed,
            "state": task.state
        ]
        
        if let filePath = task.filePath {
            progressMap["filePath"] = filePath
        }
        
        eventSink?(progressMap)
    }
    
    func getAvailableQualities(url: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let assetURL = URL(string: url) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let asset = AVURLAsset(url: assetURL)
        asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) {
            do {
                let group = asset.mediaSelectionGroup(forMediaCharacteristic: .visual)
                var qualities: [[String: Any]] = []
                
                if let options = group?.options {
                    for (index, option) in options.enumerated() {
                        if let resolution = option.displayName.components(separatedBy: "x").last,
                           let height = Int(resolution) {
                            let width = Int(Double(height) * 16 / 9)
                            let quality: [String: Any] = [
                                "id": String(index),
                                "width": width,
                                "height": height,
                                "bitrate": option.estimatedDataRate,
                                "codec": option.mediaSubTypes.first?.rawValue ?? "h264",
                                "isHDR": option.propertyList["HDR"] as? Bool ?? false,
                                "label": option.displayName
                            ]
                            qualities.append(quality)
                        }
                    }
                }
                completion(.success(qualities))
            }
        }
    }
} 