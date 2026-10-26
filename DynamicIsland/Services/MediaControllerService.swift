import Foundation
import AppKit
import Combine

@MainActor
public final class MediaControllerService: ObservableObject {
    @Published public var currentTrack = MediaTrack()
    @Published public var audioFrequencies: [CGFloat] = Array(repeating: 0.1, count: 5)
    @Published public var isShowingLyrics: Bool = false
    
    private var visualizerTimer: Timer?
    private var playbackTickerTimer: Timer?
    private var artworkCache = [String: Data]()
    private var currentArtworkFetchTask: Task<Void, Never>?
    private var lastNonZeroVolume: Double = 0.7
    
    public init() {
        setupNotificationObservers()
        syncPlayerStateFromActiveApp()
    }
    
    deinit {
        visualizerTimer?.invalidate()
        playbackTickerTimer?.invalidate()
        currentArtworkFetchTask?.cancel()
    }
    
    // MARK: - App Running Detection
    private var isSpotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }
    
    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }
    
    // MARK: - Safe AppleScript Execution (Non-Blocking)
    @discardableResult
    private nonisolated func executeAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result?.stringValue
    }
    
    // MARK: - Active Player State Real-Time Sync (Ground Truth)
    public nonisolated func syncPlayerStateFromActiveApp() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            let spotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
            let musicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
            
            if spotifyRunning {
                let script = "tell application \"Spotify\" to (player state as string) & \"|||\" & (player position as string) & \"|||\" & (duration of current track as string) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (album of current track)"
                if let raw = self.executeAppleScript(script) {
                    let parts = raw.components(separatedBy: "|||")
                    if parts.count >= 6 {
                        let stateStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let isPlaying = (stateStr == "playing" || stateStr == "kpsp")
                        let pos = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let durMs = Double(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let title = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                        let artist = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
                        let album = parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        await MainActor.run {
                            self.applySyncedState(
                                source: "Spotify",
                                title: title,
                                artist: artist,
                                album: album,
                                isPlaying: isPlaying,
                                position: pos,
                                duration: max(1, durMs / 1000)
                            )
                        }
                        return
                    }
                }
            }
            
            if musicRunning {
                let script = "tell application \"Music\" to (player state as string) & \"|||\" & (player position as string) & \"|||\" & (duration of current track as string) & \"|||\" & (name of current track) & \"|||\" & (artist of current track) & \"|||\" & (album of current track)"
                if let raw = self.executeAppleScript(script) {
                    let parts = raw.components(separatedBy: "|||")
                    if parts.count >= 6 {
                        let stateStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let isPlaying = (stateStr == "playing" || stateStr == "kpsp")
                        let pos = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let durSec = Double(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let title = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                        let artist = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
                        let album = parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        await MainActor.run {
                            self.applySyncedState(
                                source: "Apple Music",
                                title: title,
                                artist: artist,
                                album: album,
                                isPlaying: isPlaying,
                                position: pos,
                                duration: max(1, durSec)
                            )
                        }
                        return
                    }
                }
            }
            
            // If neither player is running, mark as not playing
            if !spotifyRunning && !musicRunning {
                await MainActor.run {
                    if self.currentTrack.isPlaying {
                        self.currentTrack.isPlaying = false
                    }
                }
            }
        }
    }
    
    private func applySyncedState(
        source: String,
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        position: Double,
        duration: Double
    ) {
        let trackChanged = (title != currentTrack.title || artist != currentTrack.artist)
        let wasPlaying = currentTrack.isPlaying
        currentTrack.isPlaying = isPlaying
        currentTrack.sourceAppName = source
        currentTrack.duration = duration
        
        if isPlaying != wasPlaying {
            if isPlaying {
                startVisualizer()
                startPlaybackTicker()
            } else {
                stopVisualizer()
                stopPlaybackTicker()
            }
        }
        
        // Precise position syncing: snap if track changed or drifting by more than 0.5s
        if trackChanged || abs(currentTrack.currentPosition - position) > 0.5 {
            currentTrack.currentPosition = position
        }
        
        if trackChanged {
            currentTrack.title = title.isEmpty ? "Unknown Track" : title
            currentTrack.artist = artist.isEmpty ? "Unknown Artist" : artist
            currentTrack.album = album
            currentTrack.artworkData = nil
            fetchArtwork(title: title, artist: artist, album: album, sourceApp: source)
        } else if currentTrack.artworkData == nil {
            fetchArtwork(title: title, artist: artist, album: album, sourceApp: source)
        }
    }
    
    // MARK: - Distributed Notifications (Event-Driven Immediate Sync)
    private func setupNotificationObservers() {
        // Spotify notifications
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleSpotifyNotification(notification)
            }
        }
        
        // Apple Music notifications
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAppleMusicNotification(notification)
            }
        }
    }
    
    private func handleSpotifyNotification(_ notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else {
            syncPlayerStateFromActiveApp()
            return
        }
        
        let stateStr = (info["Player State"] as? String ?? "").lowercased()
        let isPlaying = (stateStr == "playing" || stateStr == "kpsp")
        let name = info["Name"] as? String ?? currentTrack.title
        let artist = info["Artist"] as? String ?? currentTrack.artist
        let album = info["Album"] as? String ?? currentTrack.album
        
        let durationMs: Double = {
            if let num = info["Duration"] as? NSNumber { return num.doubleValue }
            if let d = info["Duration"] as? Double { return d }
            if let i = info["Duration"] as? Int { return Double(i) }
            return currentTrack.duration * 1000
        }()
        
        let position: Double = {
            if let num = info["Playback Position"] as? NSNumber { return num.doubleValue }
            if let d = info["Playback Position"] as? Double { return d }
            if let i = info["Playback Position"] as? Int { return Double(i) }
            return currentTrack.currentPosition
        }()
        
        applySyncedState(
            source: "Spotify",
            title: name,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            position: position,
            duration: max(1, durationMs / 1000)
        )
    }
    
    private func handleAppleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo as? [String: Any] else {
            syncPlayerStateFromActiveApp()
            return
        }
        
        let stateStr = (info["Player State"] as? String ?? "").lowercased()
        let isPlaying = (stateStr == "playing" || stateStr == "kpsp")
        let name = info["Name"] as? String ?? currentTrack.title
        let artist = info["Artist"] as? String ?? currentTrack.artist
        let album = info["Album"] as? String ?? currentTrack.album
        
        let totalTimeMs: Double = {
            if let num = info["Total Time"] as? NSNumber { return num.doubleValue }
            if let d = info["Total Time"] as? Double { return d }
            if let i = info["Total Time"] as? Int { return Double(i) }
            return currentTrack.duration * 1000
        }()
        
        let position: Double = {
            if let num = info["Elapsed Time"] as? NSNumber { return num.doubleValue }
            if let d = info["Elapsed Time"] as? Double { return d }
            if let i = info["Elapsed Time"] as? Int { return Double(i) }
            return currentTrack.currentPosition
        }()
        
        applySyncedState(
            source: "Apple Music",
            title: name,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            position: position,
            duration: max(1, totalTimeMs / 1000)
        )
    }
    
    // MARK: - Artwork Loading with Caching & Triple Fallback
    private func fetchArtwork(title: String, artist: String, album: String, sourceApp: String) {
        guard !title.isEmpty, title != "No Media Playing", title != "Unknown Track" else { return }
        let cacheKey = "\(title)-\(artist)"
        if let cached = artworkCache[cacheKey] {
            self.currentTrack.artworkData = cached
            return
        }
        
        currentArtworkFetchTask?.cancel()
        currentArtworkFetchTask = Task { [weak self] in
            // 1. Try Spotify AppleScript if source is Spotify
            if sourceApp == "Spotify" && (self?.isSpotifyRunning ?? false) {
                if let urlStr = self?.executeAppleScript("tell application \"Spotify\" to get artwork url of current track"),
                   let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)),
                   !urlStr.isEmpty {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self?.artworkCache[cacheKey] = data
                            self?.currentTrack.artworkData = data
                        }
                        return
                    }
                }
            }
            
            // 2. Try Apple Music AppleScript if source is Apple Music
            if sourceApp == "Apple Music" && (self?.isMusicRunning ?? false) {
                let script = """
                tell application "Music"
                    try
                        if (count of artworks of current track) > 0 then
                            set artData to raw data of artwork 1 of current track
                            set tempPath to ((path to temporary items as text) & "music_art.jpg")
                            set fileRef to (open for access file tempPath with write permission)
                            set eof of fileRef to 0
                            write artData to fileRef
                            close access fileRef
                            return POSIX path of tempPath
                        end if
                    end try
                    return ""
                end tell
                """
                if let path = self?.executeAppleScript(script), !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: cleanedPath)), !data.isEmpty {
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self?.artworkCache[cacheKey] = data
                            self?.currentTrack.artworkData = data
                        }
                        return
                    }
                }
            }
            
            // 3. Fallback: Query iTunes Search API (Free, high-resolution 512x512 artwork)
            let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let searchURL = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1") else { return }
            
            do {
                let (searchData, _) = try await URLSession.shared.data(from: searchURL)
                guard !Task.isCancelled else { return }
                if let json = try? JSONSerialization.jsonObject(with: searchData) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first,
                   let artUrlString = first["artworkUrl100"] as? String {
                    let highResString = artUrlString.replacingOccurrences(of: "100x100bb", with: "512x512bb")
                    if let highResURL = URL(string: highResString) {
                        let (imgData, _) = try await URLSession.shared.data(from: highResURL)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self?.artworkCache[cacheKey] = imgData
                            self?.currentTrack.artworkData = imgData
                        }
                    }
                }
            } catch {
                // Silently fallback to placeholder icon
            }
        }
    }
    
    // MARK: - Playback Controls (Optimistic UI + Verified Sync)
    public func togglePlayPause() {
        let isSpotify = (currentTrack.sourceAppName == "Spotify" || isSpotifyRunning) && isSpotifyRunning
        let isMusic = (currentTrack.sourceAppName == "Apple Music" || isMusicRunning) && isMusicRunning
        
        // Immediate optimistic UI flip for responsive feel
        currentTrack.isPlaying.toggle()
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            if isSpotify {
                _ = self.executeAppleScript("tell application \"Spotify\" to playpause")
            } else if isMusic {
                _ = self.executeAppleScript("tell application \"Music\" to playpause")
            } else {
                await MainActor.run {
                    self.sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
                }
            }
            
            // Allow 120ms for the media player to process, then confirm ground truth state
            try? await Task.sleep(nanoseconds: 120_000_000)
            self.syncPlayerStateFromActiveApp()
        }
    }
    
    public func nextTrack() {
        let isSpotify = (currentTrack.sourceAppName == "Spotify" || isSpotifyRunning) && isSpotifyRunning
        let isMusic = (currentTrack.sourceAppName == "Apple Music" || isMusicRunning) && isMusicRunning
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            if isSpotify {
                _ = self.executeAppleScript("tell application \"Spotify\" to next track")
            } else if isMusic {
                _ = self.executeAppleScript("tell application \"Music\" to next track")
            } else {
                await MainActor.run {
                    self.sendSystemMediaKey(key: 19) // NX_KEYTYPE_NEXT
                }
            }
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.syncPlayerStateFromActiveApp()
        }
    }
    
    public func previousTrack() {
        let isSpotify = (currentTrack.sourceAppName == "Spotify" || isSpotifyRunning) && isSpotifyRunning
        let isMusic = (currentTrack.sourceAppName == "Apple Music" || isMusicRunning) && isMusicRunning
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            if isSpotify {
                _ = self.executeAppleScript("tell application \"Spotify\" to previous track")
            } else if isMusic {
                _ = self.executeAppleScript("tell application \"Music\" to previous track")
            } else {
                await MainActor.run {
                    self.sendSystemMediaKey(key: 20) // NX_KEYTYPE_PREVIOUS
                }
            }
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.syncPlayerStateFromActiveApp()
        }
    }
    
    public func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, currentTrack.duration))
        currentTrack.currentPosition = clamped
        
        let isSpotify = (currentTrack.sourceAppName == "Spotify" || isSpotifyRunning) && isSpotifyRunning
        let isMusic = (currentTrack.sourceAppName == "Apple Music" || isMusicRunning) && isMusicRunning
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            if isSpotify {
                _ = self.executeAppleScript("tell application \"Spotify\" to set player position to \(clamped)")
            } else if isMusic {
                _ = self.executeAppleScript("tell application \"Music\" to set player position to \(clamped)")
            }
        }
    }
    
    public func seekRelative(seconds: Double) {
        seek(to: currentTrack.currentPosition + seconds)
    }
    
    public func setVolume(_ volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        currentTrack.volume = clamped
        let percent = Int(clamped * 100)
        
        let isSpotify = (currentTrack.sourceAppName == "Spotify" || isSpotifyRunning) && isSpotifyRunning
        let isMusic = (currentTrack.sourceAppName == "Apple Music" || isMusicRunning) && isMusicRunning
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            if isSpotify {
                _ = self.executeAppleScript("tell application \"Spotify\" to set sound volume to \(percent)")
            } else if isMusic {
                _ = self.executeAppleScript("tell application \"Music\" to set sound volume to \(percent)")
            }
            _ = self.executeAppleScript("set volume output volume \(percent)")
        }
    }
    
    public func toggleMute() {
        if currentTrack.volume > 0.03 {
            lastNonZeroVolume = currentTrack.volume
            setVolume(0.0)
        } else {
            setVolume(lastNonZeroVolume > 0.05 ? lastNonZeroVolume : 0.7)
        }
    }
    
    private func sendSystemMediaKey(key: Int32) {
        func postKey(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            
            if let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                ev.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        
        postKey(down: true)
        postKey(down: false)
    }
    
    // MARK: - Playback Ticker & Visualizer
    private var tickerTickCount: Int = 0
    
    private func startPlaybackTicker() {
        playbackTickerTimer?.invalidate()
        tickerTickCount = 0
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.currentTrack.isPlaying {
                    if self.currentTrack.currentPosition < self.currentTrack.duration {
                        self.currentTrack.currentPosition += 1.0
                    }
                    self.tickerTickCount += 1
                    // Actively resync ground truth position from Spotify/Music every 2s to eliminate drift
                    if self.tickerTickCount % 2 == 0 {
                        self.syncPlayerPositionOnly()
                    }
                } else {
                    self.stopPlaybackTicker()
                }
            }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        playbackTickerTimer = timer
    }
    
    public nonisolated func syncPlayerPositionOnly() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            let spotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
            let musicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
            
            if spotifyRunning {
                let script = "tell application \"Spotify\" to (player position as string) & \"|||\" & (player state as string)"
                if let raw = self.executeAppleScript(script) {
                    let parts = raw.components(separatedBy: "|||")
                    if parts.count >= 2 {
                        let pos = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let state = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let isPlaying = (state == "playing" || state == "kpsp")
                        await MainActor.run {
                            self.currentTrack.isPlaying = isPlaying
                            if abs(self.currentTrack.currentPosition - pos) > 0.5 {
                                self.currentTrack.currentPosition = pos
                            }
                        }
                        return
                    }
                }
            }
            
            if musicRunning {
                let script = "tell application \"Music\" to (player position as string) & \"|||\" & (player state as string)"
                if let raw = self.executeAppleScript(script) {
                    let parts = raw.components(separatedBy: "|||")
                    if parts.count >= 2 {
                        let pos = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        let state = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let isPlaying = (state == "playing" || state == "kpsp")
                        await MainActor.run {
                            self.currentTrack.isPlaying = isPlaying
                            if abs(self.currentTrack.currentPosition - pos) > 0.5 {
                                self.currentTrack.currentPosition = pos
                            }
                        }
                        return
                    }
                }
            }
        }
    }
    
    private func stopPlaybackTicker() {
        playbackTickerTimer?.invalidate()
        playbackTickerTimer = nil
    }
    
    private func startVisualizer() {
        visualizerTimer?.invalidate()
        guard currentTrack.isPlaying else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.currentTrack.isPlaying {
                    self.audioFrequencies = (0..<5).map { _ in CGFloat.random(in: 0.25...1.0) }
                } else {
                    self.stopVisualizer()
                }
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        visualizerTimer = timer
    }
    
    private func stopVisualizer() {
        visualizerTimer?.invalidate()
        visualizerTimer = nil
        self.audioFrequencies = [0.15, 0.15, 0.15, 0.15, 0.15]
    }
    
    public func openSourceApp() {
        let source = currentTrack.sourceAppName.lowercased()
        if source.contains("spotify") {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            } else {
                NSWorkspace.shared.open(URL(string: "spotify:")!)
            }
        } else if source.contains("apple") || (source.contains("music") && !source.contains("youtube")) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
        } else {
            // Default to YouTube Music web app
            if let url = URL(string: "https://music.youtube.com") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

