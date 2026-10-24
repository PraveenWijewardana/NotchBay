import Foundation

public struct NetworkDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let downBytesPerSec: Double
    public let upBytesPerSec: Double
    
    public init(timestamp: Date = Date(), downBytesPerSec: Double, upBytesPerSec: Double) {
        self.timestamp = timestamp
        self.downBytesPerSec = downBytesPerSec
        self.upBytesPerSec = upBytesPerSec
    }
}

public struct NetworkMetrics: Sendable {
    public var currentDownSpeed: Double = 0
    public var currentUpSpeed: Double = 0
    public var peakDownSpeed: Double = 0
    public var peakUpSpeed: Double = 0
    public var sessionDownloadedBytes: UInt64 = 0
    public var sessionUploadedBytes: UInt64 = 0
    public var history: [NetworkDataPoint] = []
    
    public static func formatSpeed(_ bytesPerSec: Double) -> String {
        let absBytes = abs(bytesPerSec)
        if absBytes >= 1_073_741_824 { // 1 GB/s
            return String(format: "%.2f GB/s", bytesPerSec / 1_073_741_824.0)
        } else if absBytes >= 1_048_576 { // 1 MB/s
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576.0)
        } else if absBytes >= 1024 { // 1 KB/s
            return String(format: "%.0f KB/s", bytesPerSec / 1024.0)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }
    
    public static func formatBytes(_ bytes: UInt64) -> String {
        let doubleBytes = Double(bytes)
        if doubleBytes >= 1_073_741_824 { // 1 GB
            return String(format: "%.2f GB", doubleBytes / 1_073_741_824.0)
        } else if doubleBytes >= 1_048_576 { // 1 MB
            return String(format: "%.1f MB", doubleBytes / 1_048_576.0)
        } else if doubleBytes >= 1024 { // 1 KB
            return String(format: "%.0f KB", doubleBytes / 1024.0)
        } else {
            return "\(bytes) B"
        }
    }
}
