import Foundation

public struct CPUMetrics: Sendable {
    public var usagePercentage: Double = 0.0
    public var userPercentage: Double = 0.0
    public var systemPercentage: Double = 0.0
    public var idlePercentage: Double = 100.0
    public var coreLoads: [Double] = []
    public var history: [Double] = Array(repeating: 0.0, count: 24)
    public var peakPercentage: Double = 0.0
}

public struct GPUMetrics: Sendable {
    public var usagePercentage: Double = 0.0
    public var tilerPercentage: Double = 0.0
    public var rendererPercentage: Double = 0.0
    public var memoryInUseBytes: UInt64 = 0
    public var history: [Double] = Array(repeating: 0.0, count: 24)
}

public struct MemoryMetrics: Sendable {
    public var usedBytes: UInt64 = 0
    public var totalBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    
    public var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }
    
    public var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
    }
    
    public var activeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(activeBytes), countStyle: .memory)
    }
    
    public var wiredFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(wiredBytes), countStyle: .memory)
    }
    
    public var compressedFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(compressedBytes), countStyle: .memory)
    }
    
    public var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .memory)
    }
    
    public var usageFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

public struct StorageMetrics: Sendable {
    public var volumeName: String = "Macintosh HD"
    public var freeBytes: UInt64 = 0
    public var totalBytes: UInt64 = 0
    
    public var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .file)
    }
    
    public var usedFormatted: String {
        let used = totalBytes >= freeBytes ? totalBytes - freeBytes : 0
        return ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)
    }
    
    public var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(totalBytes - freeBytes) / Double(totalBytes)
    }
}

public struct DiskIOMetrics: Sendable {
    public var readBytesPerSec: Double = 0
    public var writeBytesPerSec: Double = 0
    public var totalReadBytes: UInt64 = 0
    public var totalWriteBytes: UInt64 = 0
    
    public var readFormatted: String {
        "R \(formatRate(readBytesPerSec))"
    }
    
    public var writeFormatted: String {
        "W \(formatRate(writeBytesPerSec))"
    }
    
    public static func formatRate(_ bytesPerSec: Double) -> String {
        let absBytes = abs(bytesPerSec)
        if absBytes >= 1_073_741_824 {
            return String(format: "%.2f GB/s", bytesPerSec / 1_073_741_824.0)
        } else if absBytes >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576.0)
        } else if absBytes >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSec / 1024.0)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        Self.formatRate(bytesPerSec)
    }
}

public struct PowerMetrics: Sendable {
    public var batteryLevel: Int = 100
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = true
    public var powerSourceState: String = "Battery Power"
    public var timeToEmptyMinutes: Int = -1
    public var thermalState: String = "Cool"
    public var isLowPowerMode: Bool = false
    
    public var timeRemainingFormatted: String {
        if isCharging {
            return "Charging"
        } else if timeToEmptyMinutes > 0 {
            let hours = timeToEmptyMinutes / 60
            let mins = timeToEmptyMinutes % 60
            return "\(hours)h \(mins)m remaining"
        } else {
            return isPluggedIn ? "Fully Charged" : "Calculating..."
        }
    }
    
    public var statusDescription: String {
        var parts: [String] = [thermalState]
        if isLowPowerMode {
            parts.append("Low Power")
        } else if isCharging {
            parts.append("Charging")
        } else if !isPluggedIn {
            parts.append("Battery")
        }
        return parts.joined(separator: " • ")
    }
}
