import Foundation
import AVFoundation
import Flutter

class AwesomeVideoDownloader: NSObject, FlutterStreamHandler {
    private var downloadSession: AVAssetDownloadURLSession?
    private var mp4DownloadSession: URLSession?
    private var activeTasks: [String: AVAssetDownloadTask] = [:]
    private var mp4Tasks: [String: URLSessionDownloadTask] = [:]
    private var downloadLocations: [String: URL] = [:]
    private var eventSinks: [String: FlutterEventSink] = [:]
    private var playableStatusSinks: [String: FlutterEventSink] = [:]
    private var downloadProgress: [String: Double] = [:] // Track progress for each download
    private var lastProgressUpdate: [String: Date] = [:] // Track last update time for each task
    private let progressUpdateInterval: TimeInterval = 1.0 // Update progress every second
    
    private let userDefaults = UserDefaults.standard
    private let downloadLocationsKey = "com.awesome_video_downloader.downloadLocations"
    
    override init() {
        super.init()
        setupDownloadSession()
        restoreDownloadLocations()
    }
    
    private func setupDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.awesome_video_downloader.background")
        configuration.allowsCellularAccess = true
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.shouldUseExtendedBackgroundIdleMode = true
        
        downloadSession = AVAssetDownloadURLSession(configuration: configuration,
                                                  assetDownloadDelegate: self,
                                                  delegateQueue: OperationQueue.main)
        
        let mp4Configuration = URLSessionConfiguration.default
        mp4Configuration.allowsCellularAccess = true
        mp4Configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        mp4Configuration.timeoutIntervalForRequest = 30
        mp4Configuration.timeoutIntervalForResource = 300
        
        mp4DownloadSession = URLSession(configuration: mp4Configuration,
                                      delegate: self,
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
        
        mp4DownloadSession?.getAllTasks { tasks in
            for task in tasks {
                if let downloadTask = task as? URLSessionDownloadTask,
                   let taskId = downloadTask.taskDescription {
                    self.mp4Tasks[taskId] = downloadTask
                    self.downloadProgress[taskId] = 0.0
                }
            }
        }
    }
    
    private func restoreDownloadLocations() {
        if let savedLocations = userDefaults.dictionary(forKey: downloadLocationsKey) as? [String: String] {
            downloadLocations = savedLocations.compactMapValues { URL(string: $0) }
            
            // Verify files still exist and clean up if they don't
            downloadLocations = downloadLocations.filter { (taskId, location) in
                let exists = FileManager.default.fileExists(atPath: location.path)
                if !exists {
                    removeDownloadLocation(taskId)
                }
                return exists
            }
        }
    }
    
    private func saveDownloadLocation(_ taskId: String, location: URL) {
        downloadLocations[taskId] = location
        
        // Convert URLs to strings for storage
        let locationsToSave = downloadLocations.mapValues { $0.absoluteString }
        userDefaults.set(locationsToSave, forKey: downloadLocationsKey)
        userDefaults.synchronize()
    }
    
    private func removeDownloadLocation(_ taskId: String) {
        downloadLocations.removeValue(forKey: taskId)
        
        // Update stored locations
        let locationsToSave = downloadLocations.mapValues { $0.absoluteString }
        userDefaults.set(locationsToSave, forKey: downloadLocationsKey)
        userDefaults.synchronize()
    }
    
    func startDownload(
        url: String,
        title: String,
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool,
        completion: @escaping (String?) -> Void
    ) {
        guard let assetURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        let taskId = UUID().uuidString
        
        if url.lowercased().hasSuffix(".mp4") {
            startMP4Download(url: assetURL, taskId: taskId, completion: completion)
        } else if url.lowercased().contains(".m3u8") {
            startHLSDownload(url: assetURL, taskId: taskId, title: title, minimumBitrate: minimumBitrate, prefersHDR: prefersHDR, prefersMultichannel: prefersMultichannel, completion: completion)
        } else if url.lowercased().contains(".mpd") {
            startDASHDownload(url: assetURL, taskId: taskId, title: title, minimumBitrate: minimumBitrate, prefersHDR: prefersHDR, prefersMultichannel: prefersMultichannel, completion: completion)
        } else {
            // Default to HLS/DASH download for unknown formats
            startHLSDownload(url: assetURL, taskId: taskId, title: title, minimumBitrate: minimumBitrate, prefersHDR: prefersHDR, prefersMultichannel: prefersMultichannel, completion: completion)
        }
    }
    
    private func startMP4Download(url: URL, taskId: String, completion: @escaping (String?) -> Void) {
        guard let session = mp4DownloadSession else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let task = session.downloadTask(with: request)
        task.taskDescription = taskId
        mp4Tasks[taskId] = task
        downloadProgress[taskId] = 0.0
        
        initializeEventSink(taskId: taskId)
        task.resume()
        completion(taskId)
    }
    
    private func startHLSDownload(
        url: URL,
        taskId: String,
        title: String,
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool,
        completion: @escaping (String?) -> Void
    ) {
        startAVAssetDownload(
            url: url,
            taskId: taskId,
            title: title,
            minimumBitrate: minimumBitrate,
            prefersHDR: prefersHDR,
            prefersMultichannel: prefersMultichannel,
            completion: completion
        )
    }
    
    private func startDASHDownload(
        url: URL,
        taskId: String,
        title: String,
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool,
        completion: @escaping (String?) -> Void
    ) {
        startAVAssetDownload(
            url: url,
            taskId: taskId,
            title: title,
            minimumBitrate: minimumBitrate,
            prefersHDR: prefersHDR,
            prefersMultichannel: prefersMultichannel,
            completion: completion
        )
    }
    
    private func startAVAssetDownload(
        url: URL,
        taskId: String,
        title: String,
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool,
        completion: @escaping (String?) -> Void
    ) {
        guard let session = downloadSession else {
            completion(nil)
            return
        }
        
        let asset = AVURLAsset(url: url)
        var options = createAVAssetDownloadOptions(
            minimumBitrate: minimumBitrate,
            prefersHDR: prefersHDR,
            prefersMultichannel: prefersMultichannel
        )
        
        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title,
            assetArtworkData: nil,
            options: options
        ) else {
            completion(nil)
            return
        }
        
        task.taskDescription = taskId
        activeTasks[taskId] = task
        downloadProgress[taskId] = 0.0
        task.resume()
        completion(taskId)
    }
    
    private func createAVAssetDownloadOptions(
        minimumBitrate: Int,
        prefersHDR: Bool,
        prefersMultichannel: Bool
    ) -> [String: Any] {
        var options: [String: Any] = [
            AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: minimumBitrate
        ]
        
        if #available(iOS 14.0, *) {
            options[AVAssetDownloadTaskPrefersHDRKey] = prefersHDR
            options["AVAssetDownloadTaskPrefersMultichannel"] = prefersMultichannel
        }
        
        return options
    }
    
    private func initializeEventSink(taskId: String) {
        if let eventSink = eventSinks[taskId] {
            eventSink([
                "taskId": taskId,
                "progress": 0.0,
                "bytesDownloaded": 0,
                "totalBytes": 0
            ])
        }
    }
    
    func pauseDownload(taskId: String) {
        activeTasks[taskId]?.suspend()
        mp4Tasks[taskId]?.suspend()
    }
    
    func resumeDownload(taskId: String) {
        activeTasks[taskId]?.resume()
        mp4Tasks[taskId]?.resume()
    }
    
    func cancelDownload(taskId: String) {
        activeTasks[taskId]?.cancel()
        mp4Tasks[taskId]?.cancel()
        cleanupDownload(taskId)
    }
    
    private func cleanupDownload(_ taskId: String) {
        activeTasks.removeValue(forKey: taskId)
        mp4Tasks.removeValue(forKey: taskId)
        downloadProgress.removeValue(forKey: taskId)
        lastProgressUpdate.removeValue(forKey: taskId)  // Clean up the last update time
        eventSinks.removeValue(forKey: taskId)
        playableStatusSinks.removeValue(forKey: taskId)
    }
    
    func getActiveDownloads() -> [[String: Any]] {
        var downloads: [[String: Any]] = []
        
        // Add HLS/DASH downloads
        downloads.append(contentsOf: activeTasks.map { (taskId, task) in
            return [
                "taskId": taskId,
                "url": task.urlAsset.url.absoluteString,
                "title": task.taskDescription ?? "",
                "status": task.state.rawValue,
                "progress": downloadProgress[taskId] ?? 0.0
            ]
        })
        
        // Add MP4 downloads
        downloads.append(contentsOf: mp4Tasks.map { (taskId, task) in
            return [
                "taskId": taskId,
                "url": task.originalRequest?.url?.absoluteString ?? "",
                "title": task.taskDescription ?? "",
                "status": task.state.rawValue,
                "progress": downloadProgress[taskId] ?? 0.0
            ]
        })
        
        return downloads
    }
    
    func isVideoPlayableOffline(taskId: String) -> Bool {
        guard let location = downloadLocations[taskId] else { return false }
        
        // For MP4 files, just check if the file exists
        if location.pathExtension.lowercased() == "mp4" {
            return FileManager.default.fileExists(atPath: location.path)
        }
        
        // For HLS/DASH, check asset cache
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
            // For HLS/DASH videos, we need to remove the asset
            if let asset = activeTasks[taskId]?.urlAsset {
                asset.resourceLoader.preloadsEligibleContentKeys = false
                URLCache.shared.removeCachedResponse(for: URLRequest(url: asset.url))
            }
            
            // Delete the actual file
            if FileManager.default.fileExists(atPath: location.path) {
                try FileManager.default.removeItem(at: location)
            }
            
            // Clean up all references
            removeDownloadLocation(taskId)
            downloadProgress.removeValue(forKey: taskId)
            lastProgressUpdate.removeValue(forKey: taskId)
            activeTasks.removeValue(forKey: taskId)
            mp4Tasks.removeValue(forKey: taskId)
            eventSinks.removeValue(forKey: taskId)
            
            // Notify that the video is no longer playable
            if let eventSink = playableStatusSinks[taskId] {
                eventSink([
                    "taskId": taskId,
                    "isPlayable": false
                ])
            }
            playableStatusSinks.removeValue(forKey: taskId)
            
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
                var bytesReceived: Int64 = 0
                var bytesExpected: Int64 = 0
                
                if let task = activeTasks[taskId] {
                    bytesReceived = task.countOfBytesReceived
                    bytesExpected = task.countOfBytesExpectedToReceive
                } else if let task = mp4Tasks[taskId] {
                    bytesReceived = task.countOfBytesReceived
                    bytesExpected = task.countOfBytesExpectedToReceive
                }
                
                eventSink([
                    "taskId": taskId,
                    "progress": progress,
                    "bytesDownloaded": bytesReceived,
                    "totalBytes": bytesExpected
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
        
        let now = Date()
        if let lastUpdate = lastProgressUpdate[taskId],
           now.timeIntervalSince(lastUpdate) < progressUpdateInterval {
            return // Skip update if not enough time has passed
        }
        
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += CMTimeGetSeconds(loadedTimeRange.duration) /
                CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        }
        percentComplete *= 100
        
        // Store progress and update time
        downloadProgress[taskId] = percentComplete
        lastProgressUpdate[taskId] = now
        
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
        saveDownloadLocation(taskId, location: location)
        
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
        guard let taskId = task.taskDescription,
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

// MARK: - URLSessionDownloadDelegate

extension AwesomeVideoDownloader: URLSessionDownloadDelegate, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didWriteData bytesWritten: Int64,
                   totalBytesWritten: Int64,
                   totalBytesExpectedToWrite: Int64) {
        
        guard let taskId = downloadTask.taskDescription,
              let eventSink = eventSinks[taskId] else { return }
        
        let now = Date()
        if let lastUpdate = lastProgressUpdate[taskId],
           now.timeIntervalSince(lastUpdate) < progressUpdateInterval {
            return // Skip update if not enough time has passed
        }
        
        let progress = totalBytesExpectedToWrite > 0 
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100 
            : 0.0
        
        // Store progress and update time
        downloadProgress[taskId] = progress
        lastProgressUpdate[taskId] = now
        
        eventSink([
            "taskId": taskId,
            "progress": progress,
            "bytesDownloaded": totalBytesWritten,
            "totalBytes": totalBytesExpectedToWrite
        ])
    }
    
    func urlSession(_ session: URLSession,
                   downloadTask: URLSessionDownloadTask,
                   didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTask.taskDescription else { return }
        
        // Move the file to a permanent location
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("\(taskId).mp4")
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            saveDownloadLocation(taskId, location: destinationURL)
            
            // Notify that the video is now playable
            if let eventSink = playableStatusSinks[taskId] {
                eventSink([
                    "taskId": taskId,
                    "isPlayable": true
                ])
            }
            
            // Send final progress update
            if let eventSink = eventSinks[taskId] {
                eventSink([
                    "taskId": taskId,
                    "progress": 100.0,
                    "bytesDownloaded": downloadTask.countOfBytesReceived,
                    "totalBytes": downloadTask.countOfBytesExpectedToReceive
                ])
            }
        } catch {
            print("Error moving downloaded file: \(error)")
            if let eventSink = eventSinks[taskId] {
                eventSink([
                    "taskId": taskId,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    // Handle session events
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("Session became invalid with error: \(String(describing: error))")
    }
    
    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle server trust
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
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