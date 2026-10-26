import Foundation
import AppKit
import Combine

public struct ActiveTransferItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let progress: Double // 0.0 to 1.0 (if total known)
    public let isAirDrop: Bool
    public let isCompleted: Bool
    public let fileURL: URL?
    public let currentBytes: Int64
    public let totalBytes: Int64 // -1 if unknown
    public let speedBytesPerSec: Double
    
    public init(
        id: String = UUID().uuidString,
        filename: String,
        progress: Double,
        isAirDrop: Bool = false,
        isCompleted: Bool = false,
        fileURL: URL? = nil,
        currentBytes: Int64 = 0,
        totalBytes: Int64 = -1,
        speedBytesPerSec: Double = 0
    ) {
        self.id = id
        self.filename = filename
        self.progress = progress
        self.isAirDrop = isAirDrop
        self.isCompleted = isCompleted
        self.fileURL = fileURL
        self.currentBytes = currentBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSec = speedBytesPerSec
    }
    
    public var hasKnownTotal: Bool {
        totalBytes > 0
    }
    
    public var formattedCurrentSize: String {
        ByteCountFormatter.string(fromByteCount: currentBytes, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        guard totalBytes > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    public var formattedSpeed: String {
        guard speedBytesPerSec > 0 else { return "" }
        if speedBytesPerSec >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB/s", speedBytesPerSec / (1024 * 1024 * 1024))
        } else if speedBytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", speedBytesPerSec / (1024 * 1024))
        } else if speedBytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", speedBytesPerSec / 1024)
        }
        return "\(Int(speedBytesPerSec)) B/s"
    }
    
    public var progressPercentFormatted: String {
        if isCompleted {
            return "100%"
        }
        if totalBytes > 0 {
            return "\(Int(progress * 100))%"
        }
        return formattedCurrentSize
    }
    
    public var subtitleFormatted: String {
        if isCompleted {
            return "Saved to Downloads • \(formattedCurrentSize)"
        }
        if totalBytes > 0 {
            let speedStr = formattedSpeed.isEmpty ? "" : " • \(formattedSpeed)"
            return "\(formattedCurrentSize) of \(formattedTotalSize)\(speedStr)"
        } else {
            let speedStr = formattedSpeed.isEmpty ? "" : " • \(formattedSpeed)"
            return "\(formattedCurrentSize)\(speedStr)"
        }
    }
}

@MainActor
public final class FileTransferService: ObservableObject {
    @Published public var activeTransfer: ActiveTransferItem? = nil
    public var onTransferChanged: ((ActiveTransferItem?) -> Void)?
    
    private var monitorTimer: Timer?
    private let downloadsURL: URL
    private var knownFiles: [String: Int64] = [:]
    private var lastBytesMap: [String: Int64] = [:]
    private var lastPollTime: Date = Date()
    private var dismissTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        self.downloadsURL = downloads
        
        // Listen to settings toggle
        AppSettings.shared.$enableAirDropAlerts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
        
        // Only start monitoring if explicitly enabled by the user in Settings
        if AppSettings.shared.enableAirDropAlerts {
            startMonitoring()
        }
    }
    
    deinit {
        monitorTimer?.invalidate()
        dismissTimer?.invalidate()
    }
    
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        activeTransfer = nil
        lastBytesMap.removeAll()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        guard AppSettings.shared.enableAirDropAlerts else { return }
        
        // Try reading once; if permission is denied, stop permanently so macOS TCC does NOT loop!
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            for file in contents {
                let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                knownFiles[file.lastPathComponent] = size
            }
        } catch {
            // Permission not granted or denied - stop immediately and do not loop!
            stopMonitoring()
            return
        }
        
        lastPollTime = Date()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForTransferActivity()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer
    }
    
    private func checkForTransferActivity() {
        guard AppSettings.shared.enableAirDropAlerts else {
            stopMonitoring()
            return
        }
        
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            // Access denied or revoked - immediately stop timer to prevent system prompt loops!
            stopMonitoring()
            return
        }
        
        let now = Date()
        let timeDelta = max(0.1, now.timeIntervalSince(lastPollTime))
        lastPollTime = now
        
        // 1. Look for active browser download files (.crdownload, .download, .part)
        let downloadExtensions = ["crdownload", "download", "part"]
        if let activeDown = contents.first(where: { downloadExtensions.contains($0.pathExtension.lowercased()) }) {
            let metrics = getDownloadMetrics(for: activeDown)
            let prevBytes = lastBytesMap[metrics.filename] ?? metrics.current
            let byteDiff = max(0, metrics.current - prevBytes)
            lastBytesMap[metrics.filename] = metrics.current
            
            let speed = Double(byteDiff) / timeDelta
            
            let progress: Double
            if metrics.total > 0 {
                progress = min(0.99, max(0.01, Double(metrics.current) / Double(metrics.total)))
            } else {
                progress = 0.0
            }
            
            let item = ActiveTransferItem(
                filename: metrics.filename,
                progress: progress,
                isAirDrop: false,
                isCompleted: false,
                fileURL: activeDown,
                currentBytes: metrics.current,
                totalBytes: metrics.total,
                speedBytesPerSec: speed
            )
            self.activeTransfer = item
            onTransferChanged?(item)
            return
        } else if activeTransfer != nil && activeTransfer?.isCompleted == false {
            // No active .download / .crdownload file found, but activeTransfer was downloading.
            // Check if it just completed into a finalized file in ~/Downloads
            lastBytesMap.removeAll()
        }
        
        // 2. Look for newly arrived files (AirDrop arrivals or completed downloads)
        for file in contents {
            let name = file.lastPathComponent
            guard !downloadExtensions.contains(file.pathExtension.lowercased()) else { continue }
            
            if knownFiles[name] == nil {
                let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey])
                let currentSize = Int64(resourceValues?.fileSize ?? 0)
                knownFiles[name] = currentSize
                
                // Only alert if file was modified or created in the last 15 seconds
                let modDate = resourceValues?.contentModificationDate ?? resourceValues?.creationDate ?? Date.distantPast
                let isRecent = abs(Date().timeIntervalSince(modDate)) < 15.0
                guard isRecent else { continue }
                
                let isAirDrop = Self.isAirDropFile(at: file)
                let wasDownloading = (activeTransfer != nil && activeTransfer?.isCompleted == false)
                
                // Only show transfer alert if genuinely from AirDrop or completed an active browser download
                guard isAirDrop || wasDownloading else { continue }
                
                let item = ActiveTransferItem(
                    filename: name,
                    progress: 1.0,
                    isAirDrop: isAirDrop,
                    isCompleted: true,
                    fileURL: file,
                    currentBytes: currentSize,
                    totalBytes: currentSize,
                    speedBytesPerSec: 0
                )
                self.activeTransfer = item
                NSSound(named: "Glass")?.play()
                onTransferChanged?(item)
                
                // Keep completed banner for 3.5 seconds
                dismissTimer?.invalidate()
                dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        if self?.activeTransfer?.isCompleted == true {
                            self?.activeTransfer = nil
                            self?.onTransferChanged?(nil)
                        }
                    }
                }
                return
            }
        }
    }
    
    // MARK: - AirDrop Detection Verification
    public static func isAirDropEnabled() -> Bool {
        // AirDrop discoverability state in macOS is stored in com.apple.sharingd DiscoverableMode
        if let mode = CFPreferencesCopyAppValue("DiscoverableMode" as CFString, "com.apple.sharingd" as CFString) as? String {
            return mode.caseInsensitiveCompare("Off") != .orderedSame
        }
        return false
    }
    
    public static func isAirDropFile(at url: URL) -> Bool {
        // If AirDrop is turned Off, it is impossible for a file to have arrived via AirDrop
        guard isAirDropEnabled() else { return false }
        
        let path = url.path
        
        // 1. Check for explicit com.apple.AirDrop extended attribute
        var buffer = [CChar](repeating: 0, count: 256)
        if getxattr(path, "com.apple.AirDrop", &buffer, buffer.count, 0, 0) > 0 {
            return true
        }
        
        // 2. Check for com.apple.quarantine attribute containing "sharingd"
        var qBuffer = [CChar](repeating: 0, count: 1024)
        let qLen = getxattr(path, "com.apple.quarantine", &qBuffer, qBuffer.count, 0, 0)
        if qLen > 0 {
            let qStr = String(cString: qBuffer)
            if qStr.localizedCaseInsensitiveContains("sharingd") || qStr.localizedCaseInsensitiveContains("airdrop") {
                return true
            }
        }
        
        return false
    }
    
    private func getDownloadMetrics(for url: URL) -> (current: Int64, total: Int64, filename: String) {
        let ext = url.pathExtension.lowercased()
        var current: Int64 = 0
        var total: Int64 = -1
        var cleanFilename = url.deletingPathExtension().lastPathComponent
        
        if ext == "download" {
            // Safari .download directory bundle
            let plistURL = url.appendingPathComponent("Info.plist")
            if let dict = NSDictionary(contentsOf: plistURL) {
                if let exp = dict["NSURLDownloadBytesExpected"] as? NSNumber, exp.int64Value > 0 {
                    total = exp.int64Value
                } else if let exp = dict["DownloadEntryProgressTotalToLoad"] as? NSNumber, exp.int64Value > 0 {
                    total = exp.int64Value
                }
                
                if let rec = dict["NSURLDownloadBytesReceived"] as? NSNumber, rec.int64Value > 0 {
                    current = rec.int64Value
                } else if let rec = dict["DownloadEntryProgressBytesSoFar"] as? NSNumber, rec.int64Value > 0 {
                    current = rec.int64Value
                }
                
                if let resume = dict["DownloadEntryResumeInformation"] as? [String: Any] {
                    if total <= 0, let exp = resume["NSURLDownloadBytesExpected"] as? NSNumber, exp.int64Value > 0 {
                        total = exp.int64Value
                    }
                    if current <= 0, let rec = resume["NSURLDownloadBytesReceived"] as? NSNumber, rec.int64Value > 0 {
                        current = rec.int64Value
                    }
                }
            }
            
            // Measure actual files inside bundle if current is 0
            if let innerFiles = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for inner in innerFiles where inner.lastPathComponent != "Info.plist" {
                    cleanFilename = inner.lastPathComponent
                    let size = Int64((try? inner.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                    if size > current {
                        current = size
                    }
                }
            }
        } else {
            // Chrome (.crdownload) or Firefox (.part)
            current = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            
            // If cleanFilename still has another extension e.g. "image.png" from "image.png.crdownload"
            if cleanFilename.isEmpty {
                cleanFilename = url.lastPathComponent
            }
        }
        
        return (current, total, cleanFilename)
    }
    
    public func openFileInFinder() {
        guard let url = activeTransfer?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
