import Foundation
import IOKit
import IOKit.ps
import MachO
import Combine

@MainActor
public final class SystemMonitorService: ObservableObject {
    @Published public var cpuMetrics = CPUMetrics()
    @Published public var gpuMetrics = GPUMetrics()
    @Published public var memoryMetrics = MemoryMetrics()
    @Published public var storageMetrics = StorageMetrics()
    @Published public var diskIOMetrics = DiskIOMetrics()
    @Published public var powerMetrics = PowerMetrics()
    
    private var timer: Timer?
    private var previousCPUInfo: processor_info_array_t?
    private var previousCPUInfoCount: mach_msg_type_number_t = 0
    private var previousDiskReadBytes: UInt64 = 0
    private var previousDiskWriteBytes: UInt64 = 0
    private var previousDiskSampleTime: Date = Date()
    private var isDiskInitialized = false
    
    public init() {
        refreshAll()
        startMonitoring()
    }
    
    public func startMonitoring(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func refreshAll() {
        updateCPU()
        updateMemory()
        updateStorage()
        updateDiskIO()
        updatePower()
        updateGPU()
    }
    
    // MARK: - CPU Monitoring (100% Real Darwin mach_host)
    private func updateCPU() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }
        
        if let previousCPUInfo = previousCPUInfo {
            var totalUser: Double = 0
            var totalSystem: Double = 0
            var totalIdle: Double = 0
            var totalUsage: Double = 0
            var coreLoads: [Double] = []
            
            for i in 0..<Int(numCPUs) {
                let base = Int32(CPU_STATE_MAX) * Int32(i)
                let user = Double(cpuInfo[Int(base + CPU_STATE_USER)] - previousCPUInfo[Int(base + CPU_STATE_USER)])
                let system = Double(cpuInfo[Int(base + CPU_STATE_SYSTEM)] - previousCPUInfo[Int(base + CPU_STATE_SYSTEM)])
                let nice = Double(cpuInfo[Int(base + CPU_STATE_NICE)] - previousCPUInfo[Int(base + CPU_STATE_NICE)])
                let idle = Double(cpuInfo[Int(base + CPU_STATE_IDLE)] - previousCPUInfo[Int(base + CPU_STATE_IDLE)])
                
                let used = user + system + nice
                let total = max(1.0, used + idle)
                let load = (used / total) * 100.0
                
                coreLoads.append(load)
                totalUser += (user / total) * 100.0
                totalSystem += (system / total) * 100.0
                totalIdle += (idle / total) * 100.0
                totalUsage += load
            }
            
            let avgUsage = totalUsage / Double(numCPUs)
            cpuMetrics.usagePercentage = avgUsage
            cpuMetrics.userPercentage = totalUser / Double(numCPUs)
            cpuMetrics.systemPercentage = totalSystem / Double(numCPUs)
            cpuMetrics.idlePercentage = totalIdle / Double(numCPUs)
            cpuMetrics.coreLoads = coreLoads
            
            if avgUsage > cpuMetrics.peakPercentage {
                cpuMetrics.peakPercentage = avgUsage
            }
            
            var hist = cpuMetrics.history
            if hist.count >= 24 { hist.removeFirst() }
            hist.append(avgUsage)
            cpuMetrics.history = hist
            
            let prevSize = vm_size_t(previousCPUInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: previousCPUInfo)), prevSize)
        }
        
        previousCPUInfo = cpuInfo
        previousCPUInfoCount = numCPUInfo
    }
    
    // MARK: - Memory Monitoring (100% Real vm_statistics64)
    private func updateMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        var pageSize: vm_size_t = 4096
        _ = host_page_size(mach_host_self(), &pageSize)
        
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let used = active + wired + compressed
        
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        
        // Swap usage
        var xsw = xsw_usage()
        var xswSize = MemoryLayout<xsw_usage>.size
        var swapUsed: UInt64 = 0
        var swapTotal: UInt64 = 0
        if sysctlbyname("vm.swapusage", &xsw, &xswSize, nil, 0) == 0 {
            swapUsed = xsw.xsu_used
            swapTotal = xsw.xsu_total
        }
        
        memoryMetrics = MemoryMetrics(
            usedBytes: used,
            totalBytes: totalMemory > 0 ? totalMemory : 16 * 1024 * 1024 * 1024,
            activeBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal
        )
    }
    
    // MARK: - Storage Monitoring (100% Real Volume Attributes)
    private func updateStorage() {
        let fileURL = URL(fileURLWithPath: "/")
        if let values = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey, .volumeLocalizedNameKey]) {
            let free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let name = values.volumeLocalizedName ?? "Macintosh HD"
            storageMetrics = StorageMetrics(volumeName: name, freeBytes: free, totalBytes: total)
        } else {
            var stat = statfs()
            if statfs("/", &stat) == 0 {
                let free = UInt64(stat.f_bavail) * UInt64(stat.f_bsize)
                let total = UInt64(stat.f_blocks) * UInt64(stat.f_bsize)
                storageMetrics = StorageMetrics(volumeName: "Macintosh HD", freeBytes: free, totalBytes: total)
            }
        }
    }
    
    // MARK: - Disk I/O Monitoring (100% Real IOKit IOBlockStorageDriver)
    private func updateDiskIO() {
        var iterator = io_iterator_t()
        let match = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else { return }
        
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var entry = IOIteratorNext(iterator)
        
        while entry != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let read = stats["Bytes (Read)"] as? UInt64 ?? (stats["Bytes (Read)"] as? Int64).map({ UInt64($0) }) {
                    totalRead += read
                }
                if let write = stats["Bytes (Write)"] as? UInt64 ?? (stats["Bytes (Write)"] as? Int64).map({ UInt64($0) }) {
                    totalWrite += write
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        
        let now = Date()
        if isDiskInitialized {
            let elapsed = max(0.5, now.timeIntervalSince(previousDiskSampleTime))
            let deltaRead = totalRead >= previousDiskReadBytes ? totalRead - previousDiskReadBytes : 0
            let deltaWrite = totalWrite >= previousDiskWriteBytes ? totalWrite - previousDiskWriteBytes : 0
            
            diskIOMetrics = DiskIOMetrics(
                readBytesPerSec: Double(deltaRead) / elapsed,
                writeBytesPerSec: Double(deltaWrite) / elapsed,
                totalReadBytes: totalRead,
                totalWriteBytes: totalWrite
            )
        } else {
            isDiskInitialized = true
            diskIOMetrics = DiskIOMetrics(
                readBytesPerSec: 0,
                writeBytesPerSec: 0,
                totalReadBytes: totalRead,
                totalWriteBytes: totalWrite
            )
        }
        
        previousDiskReadBytes = totalRead
        previousDiskWriteBytes = totalWrite
        previousDiskSampleTime = now
    }
    
    // MARK: - Power & Battery (100% Real IOKit.ps)
    private func updatePower() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            powerMetrics = PowerMetrics(
                batteryLevel: 100,
                isCharging: false,
                isPluggedIn: true,
                powerSourceState: "AC Power",
                timeToEmptyMinutes: -1,
                thermalState: ProcessInfo.processInfo.thermalState == .nominal ? "Cool" : "Warm",
                isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
            return
        }
        
        let currentCapacity = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 100
        let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
        let powerSourceState = desc[kIOPSPowerSourceStateKey as String] as? String ?? "Battery Power"
        let isPluggedIn = powerSourceState == (kIOPSACPowerValue as String)
        let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int ?? -1
        
        let thermalState: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "Cool"
        case .fair: thermalState = "Warm"
        case .serious: thermalState = "Hot"
        case .critical: thermalState = "Throttling"
        @unknown default: thermalState = "Cool"
        }
        
        powerMetrics = PowerMetrics(
            batteryLevel: currentCapacity,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            powerSourceState: powerSourceState,
            timeToEmptyMinutes: timeToEmpty,
            thermalState: thermalState,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
    
    // MARK: - GPU Monitoring (100% Real IOKit IOAccelerator)
    private func updateGPU() {
        var iterator = io_iterator_t()
        let match = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else { return }
        
        var maxDevUtil: Double = 0
        var tilerUtil: Double = 0
        var rendererUtil: Double = 0
        var memInUse: UInt64 = 0
        var entry = IOIteratorNext(iterator)
        
        while entry != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                if let dev = perf["Device Utilization %"] as? Double ?? (perf["Device Utilization %"] as? Int64).map({ Double($0) }) ?? (perf["Device Utilization %"] as? Int).map({ Double($0) }) {
                    maxDevUtil = max(maxDevUtil, dev)
                }
                if let tiler = perf["Tiler Utilization %"] as? Double ?? (perf["Tiler Utilization %"] as? Int64).map({ Double($0) }) {
                    tilerUtil = tiler
                }
                if let renderer = perf["Renderer Utilization %"] as? Double ?? (perf["Renderer Utilization %"] as? Int64).map({ Double($0) }) {
                    rendererUtil = renderer
                }
                if let mem = perf["In use system memory"] as? UInt64 ?? (perf["In use system memory"] as? Int64).map({ UInt64($0) }) {
                    memInUse = mem
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        
        gpuMetrics.usagePercentage = maxDevUtil
        gpuMetrics.tilerPercentage = tilerUtil
        gpuMetrics.rendererPercentage = rendererUtil
        gpuMetrics.memoryInUseBytes = memInUse
        
        var hist = gpuMetrics.history
        if hist.count >= 24 { hist.removeFirst() }
        hist.append(maxDevUtil)
        gpuMetrics.history = hist
    }
}
