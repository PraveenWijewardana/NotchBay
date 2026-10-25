import Foundation
import AppKit
import Combine

public struct ActiveTransferItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let progress: Double // 0.0 to 1.0
    public let isAirDrop: Bool
    public let isCompleted: Bool
    public let fileURL: URL?
    
    public init(
        id: String = UUID().uuidString,
        filename: String,
        progress: Double,
        isAirDrop: Bool = false,
        isCompleted: Bool = false,
        fileURL: URL? = nil
    ) {
        self.id = id
        self.filename = filename
        self.progress = progress
        self.isAirDrop = isAirDrop
        self.isCompleted = isCompleted
        self.fileURL = fileURL
    }
    
    public var progressPercentFormatted: String {
        "\(Int(progress * 100))%"
    }
}

@MainActor
public final class FileTransferService: ObservableObject {
    @Published public var activeTransfer: ActiveTransferItem? = nil
    public var onTransferChanged: ((ActiveTransferItem?) -> Void)?
    
    private var monitorTimer: Timer?
    private let downloadsURL: URL
    private var knownFiles: [String: UInt64] = [:]
    private var dismissTimer: Timer?
    
    public init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        self.downloadsURL = downloads
        
        // Populate initial file snapshot
        scanInitialDownloads()
        startMonitoring()
    }
    
    deinit {
        monitorTimer?.invalidate()
        dismissTimer?.invalidate()
    }
    
    private func scanInitialDownloads() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }
        for file in contents {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            knownFiles[file.lastPathComponent] = UInt64(size)
        }
    }
    
    public func startMonitoring() {
        monitorTimer?.invalidate()
        // Poll every 1.0s to detect incoming AirDrops or browser downloads
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForTransferActivity()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer
    }
    
    private func checkForTransferActivity() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        // 1. Look for active browser download files (.crdownload, .download, .part)
        let downloadExtensions = ["crdownload", "download", "part"]
        if let activeDown = contents.first(where: { downloadExtensions.contains($0.pathExtension.lowercased()) }) {
            let filename = activeDown.deletingPathExtension().lastPathComponent
            let currentSize = UInt64((try? activeDown.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            
            // Progressive simulation/real tracking
            let progress = min(0.95, max(0.15, activeTransfer?.filename == filename ? (activeTransfer?.progress ?? 0.15) + 0.12 : 0.25))
            
            let item = ActiveTransferItem(
                filename: filename,
                progress: progress,
                isAirDrop: false,
                isCompleted: false,
                fileURL: activeDown
            )
            self.activeTransfer = item
            onTransferChanged?(item)
            return
        }
        
        // 2. Look for newly arrived files (e.g. AirDrop / newly completed downloads)
        for file in contents {
            let name = file.lastPathComponent
            guard !downloadExtensions.contains(file.pathExtension.lowercased()) else { continue }
            
            if knownFiles[name] == nil {
                // Brand new file appeared in ~/Downloads!
                let isAirDrop = (file.pathExtension.isEmpty || ["png", "jpg", "jpeg", "heic", "mov", "mp4", "pdf", "zip"].contains(file.pathExtension.lowercased()))
                knownFiles[name] = UInt64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                
                let item = ActiveTransferItem(
                    filename: name,
                    progress: 1.0,
                    isAirDrop: isAirDrop,
                    isCompleted: true,
                    fileURL: file
                )
                self.activeTransfer = item
                NSSound(named: "Glass")?.play()
                onTransferChanged?(item)
                
                // Auto-dismiss after 4.0 seconds
                dismissTimer?.invalidate()
                dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
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
    
    public func openFileInFinder() {
        guard let url = activeTransfer?.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // Testing trigger
    public func simulateAirDropTransfer(filename: String = "IMG_4092.HEIC") {
        let item = ActiveTransferItem(
            filename: filename,
            progress: 1.0,
            isAirDrop: true,
            isCompleted: true,
            fileURL: downloadsURL.appendingPathComponent(filename)
        )
        self.activeTransfer = item
        NSSound(named: "Glass")?.play()
        onTransferChanged?(item)
        
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activeTransfer = nil
                self?.onTransferChanged?(nil)
            }
        }
    }
}
