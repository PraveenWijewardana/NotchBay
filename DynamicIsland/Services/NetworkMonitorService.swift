import Foundation
import Combine

@MainActor
public final class NetworkMonitorService: ObservableObject {
    @Published public var metrics = NetworkMetrics()
    
    private var timer: Timer?
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousSampleTime: Date = Date()
    private var hasInitialized = false
    
    public var isDetailedMonitoringActive: Bool = false {
        didSet {
            guard oldValue != isDetailedMonitoringActive else { return }
            start(interval: isDetailedMonitoringActive ? 1.0 : 3.0)
        }
    }
    
    public init() {
        start(interval: 3.0)
    }
    
    public func start(interval: TimeInterval = 3.0) {
        timer?.invalidate()
        readInterfaceBytes { [weak self] bytesIn, bytesOut in
            guard let self = self else { return }
            self.previousBytesIn = bytesIn
            self.previousBytesOut = bytesOut
            self.previousSampleTime = Date()
            self.hasInitialized = true
        }
        
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
        t.tolerance = isDetailedMonitoringActive ? 0.1 : 0.8
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func sample() {
        guard hasInitialized else { return }
        
        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(previousSampleTime))
        
        readInterfaceBytes { [weak self] currentIn, currentOut in
            guard let self = self else { return }
            
            let deltaIn = currentIn >= self.previousBytesIn ? currentIn - self.previousBytesIn : 0
            let deltaOut = currentOut >= self.previousBytesOut ? currentOut - self.previousBytesOut : 0
            
            let downSpeed = Double(deltaIn) / elapsed
            let upSpeed = Double(deltaOut) / elapsed
            
            self.metrics.currentDownSpeed = downSpeed
            self.metrics.currentUpSpeed = upSpeed
            
            if downSpeed > self.metrics.peakDownSpeed {
                self.metrics.peakDownSpeed = downSpeed
            }
            if upSpeed > self.metrics.peakUpSpeed {
                self.metrics.peakUpSpeed = upSpeed
            }
            
            self.metrics.sessionDownloadedBytes += deltaIn
            self.metrics.sessionUploadedBytes += deltaOut
            
            var hist = self.metrics.history
            if hist.count >= 30 {
                hist.removeFirst()
            }
            hist.append(NetworkDataPoint(timestamp: now, downBytesPerSec: downSpeed, upBytesPerSec: upSpeed))
            self.metrics.history = hist
            
            self.previousBytesIn = currentIn
            self.previousBytesOut = currentOut
            self.previousSampleTime = now
        }
    }
    
    private func readInterfaceBytes(completion: (UInt64, UInt64) -> Void) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else {
            completion(0, 0)
            return
        }
        defer { freeifaddrs(ifap) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = Optional(firstAddr)
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            // Focus on physical interfaces like en0, en1 (Wi-Fi and Ethernet)
            if (name.hasPrefix("en") || name.hasPrefix("pdp_ip")) && current.pointee.ifa_addr != nil {
                let family = current.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_LINK) {
                    if let data = current.pointee.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        totalIn += UInt64(networkData.pointee.ifi_ibytes)
                        totalOut += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        
        completion(totalIn, totalOut)
    }
}
