import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import Combine

@MainActor
public final class SystemHUDService: ObservableObject {
    @Published public var activeAlert: HUDAlert? = nil
    
    private var currentOutputDeviceID: AudioDeviceID = 0
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    
    private var lastReportedVolume: Float32 = -1.0
    private var lastReportedMute: UInt32 = 0
    private var isAudioSetupComplete = false
    
    // Battery tracking state
    private var previousBatteryLevel: Int = -1
    private var previousIsPluggedIn: Bool? = nil
    private var previousIsCharging: Bool? = nil
    private var hasHandledBatteryInitialState = false
    
    // Track change tracking state
    private var previousTrackTitle: String = ""
    
    public var onAlertTriggered: ((HUDAlert) -> Void)?
    
    public init() {
        setupAudioVolumeListener()
    }
    
    // MARK: - CoreAudio Hardware Volume Listener (Zero-Lag, Real-Time)
    private func setupAudioVolumeListener() {
        updateDefaultOutputDevice()
        
        // Listen for default output device changes (e.g. plugging in headphones or AirPods)
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let deviceBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDefaultOutputDeviceChanged()
            }
        }
        self.defaultDeviceListenerBlock = deviceBlock
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            deviceBlock
        )
    }
    
    private func updateDefaultOutputDevice() {
        var defaultDevice = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultDevice
        )
        
        guard status == noErr, defaultDevice != 0 else { return }
        
        if defaultDevice != currentOutputDeviceID {
            removeAudioListeners(from: currentOutputDeviceID)
            currentOutputDeviceID = defaultDevice
            attachAudioListeners(to: defaultDevice)
        }
    }
    
    private func handleDefaultOutputDeviceChanged() {
        updateDefaultOutputDevice()
    }
    
    private func attachAudioListeners(to deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        // 1. Volume Listener
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.readVolumeAndNotify()
            }
        }
        self.volumeListenerBlock = volBlock
        
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volAddress,
            DispatchQueue.main,
            volBlock
        )
        
        // 2. Mute Listener
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let mBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.readVolumeAndNotify()
            }
        }
        self.muteListenerBlock = mBlock
        
        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &muteAddress,
            DispatchQueue.main,
            mBlock
        )
        
        // Initial sample to prime values
        let initialVol = readCurrentDeviceVolume(deviceID: deviceID)
        let initialMute = readCurrentDeviceMute(deviceID: deviceID)
        self.lastReportedVolume = initialVol
        self.lastReportedMute = initialMute
        self.isAudioSetupComplete = true
    }
    
    private func removeAudioListeners(from deviceID: AudioDeviceID) {
        guard deviceID != 0 else { return }
        
        if let volBlock = volumeListenerBlock {
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, volBlock)
            self.volumeListenerBlock = nil
        }
        
        if let mBlock = muteListenerBlock {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
            self.muteListenerBlock = nil
        }
    }
    
    private func readCurrentDeviceVolume(deviceID: AudioDeviceID) -> Float32 {
        var volume = Float32(0)
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volumeSize, &volume) == noErr {
            return volume
        }
        return 0.5
    }
    
    private func readCurrentDeviceMute(deviceID: AudioDeviceID) -> UInt32 {
        var isMuted = UInt32(0)
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &isMuted) == noErr {
            return isMuted
        }
        return 0
    }
    
    private func readVolumeAndNotify() {
        guard isAudioSetupComplete else { return }
        let currentVol = readCurrentDeviceVolume(deviceID: currentOutputDeviceID)
        let currentMute = readCurrentDeviceMute(deviceID: currentOutputDeviceID)
        
        // Only trigger if value genuinely changed
        if abs(currentVol - lastReportedVolume) > 0.005 || currentMute != lastReportedMute {
            lastReportedVolume = currentVol
            lastReportedMute = currentMute
            
            let isMuted = (currentMute == 1 || currentVol < 0.01)
            let icon: String
            if isMuted {
                icon = "speaker.slash.fill"
            } else if currentVol < 0.33 {
                icon = "speaker.wave.1.fill"
            } else if currentVol < 0.66 {
                icon = "speaker.wave.2.fill"
            } else {
                icon = "speaker.wave.3.fill"
            }
            
            let percent = Int(round(currentVol * 100))
            let alert = HUDAlert(
                type: .volume(level: Double(currentVol), isMuted: isMuted),
                title: "Volume",
                subtitle: isMuted ? "Muted" : "\(percent)%",
                icon: icon,
                progress: isMuted ? 0.0 : Double(currentVol),
                isMuted: isMuted,
                duration: 2.2
            )
            triggerAlert(alert)
        }
    }
    
    // MARK: - Battery Events Monitoring (20%, 50%, Full Charge, Plug/Unplug)
    public func evaluateBatteryMetrics(_ metrics: PowerMetrics) {
        let level = metrics.batteryLevel
        let plugged = metrics.isPluggedIn
        let charging = metrics.isCharging
        
        if !hasHandledBatteryInitialState {
            previousBatteryLevel = level
            previousIsPluggedIn = plugged
            previousIsCharging = charging
            hasHandledBatteryInitialState = true
            return
        }
        
        // 1. Charger connected / disconnected event
        if let prevPlugged = previousIsPluggedIn, prevPlugged != plugged {
            if plugged {
                let timeStr = metrics.timeToFullMinutes > 0 ? "~\(metrics.timeToFullMinutes)m to full" : "Connected"
                let alert = HUDAlert(
                    type: .magSafe(level: level, isPluggedIn: true, timeRemaining: timeStr),
                    title: "MagSafe",
                    subtitle: "\(level)% • \(timeStr)",
                    icon: "bolt.ring.closed",
                    progress: Double(level) / 100.0,
                    duration: 3.5
                )
                triggerAlert(alert)
            } else {
                let alert = HUDAlert(
                    type: .battery(level: level, isCharging: false, isPluggedIn: false),
                    title: "Power Disconnected",
                    subtitle: "\(level)% on Battery",
                    icon: "battery.50",
                    progress: Double(level) / 100.0,
                    duration: 3.0
                )
                triggerAlert(alert)
            }
        }
        
        // 2. Full Charge reached (100% while plugged in)
        if level == 100 && plugged && previousBatteryLevel < 100 {
            let alert = HUDAlert(
                type: .battery(level: 100, isCharging: false, isPluggedIn: true),
                title: "Fully Charged",
                subtitle: "100% Complete",
                icon: "battery.100.bolt",
                progress: 1.0,
                duration: 3.5
            )
            triggerAlert(alert)
        }
        
        // 3. 50% Battery threshold
        if level == 50 && previousBatteryLevel != 50 && !plugged {
            let alert = HUDAlert(
                type: .battery(level: 50, isCharging: false, isPluggedIn: false),
                title: "Battery at 50%",
                subtitle: metrics.timeToEmptyMinutes > 0 ? "\(metrics.timeToEmptyMinutes / 60)h left" : "Half Power",
                icon: "battery.50",
                progress: 0.50,
                duration: 3.0
            )
            triggerAlert(alert)
        }
        
        // 4. Low Battery 20% warning
        if level == 20 && previousBatteryLevel > 20 && !plugged {
            let alert = HUDAlert(
                type: .battery(level: 20, isCharging: false, isPluggedIn: false),
                title: "Low Battery",
                subtitle: "20% Remaining",
                icon: "battery.25",
                progress: 0.20,
                duration: 4.0
            )
            triggerAlert(alert)
        }
        
        previousBatteryLevel = level
        previousIsPluggedIn = plugged
        previousIsCharging = charging
    }
    
    // MARK: - Track Change Monitoring
    public func evaluateTrackChange(_ track: MediaTrack) {
        guard track.isPlaying, !track.title.isEmpty, track.title != "No Media Playing" else { return }
        // Keep music inside compact island ears; do not pop down an oversized HUD banner over the notch
        previousTrackTitle = track.title
    }
    
    private func triggerAlert(_ alert: HUDAlert) {
        self.activeAlert = alert
        onAlertTriggered?(alert)
    }
}
