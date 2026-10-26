import SwiftUI
import AppKit

public struct NowPlayingView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var mediaService: MediaControllerService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.mediaService = viewModel.mediaService
    }
    
    private var sourceDisplayName: String {
        let name = mediaService.currentTrack.sourceAppName
        return name.isEmpty ? "Music" : name
    }
    
    private var volumeIconName: String {
        let vol = mediaService.currentTrack.volume
        if vol < 0.03 {
            return "speaker.slash.fill"
        } else if vol < 0.45 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // MARK: - 1. Top Header Row (Now Playing & Lyrics Toggle & Source App Link)
            HStack(alignment: .center) {
                Text("Now Playing")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Lyrics / Player Toggle Capsule
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        mediaService.isShowingLyrics.toggle()
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: mediaService.isShowingLyrics ? "music.note" : "quote.bubble.fill")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(mediaService.isShowingLyrics ? "Player" : "Lyrics")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(mediaService.isShowingLyrics ? Color(red: 1.0, green: 0.35, blue: 0.55) : .white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(mediaService.isShowingLyrics ? Color(red: 1.0, green: 0.25, blue: 0.5).opacity(0.2) : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(mediaService.isShowingLyrics ? "Show Player Controls" : "Show Synchronized Lyrics")
                
                Button {
                    mediaService.openSourceApp()
                } label: {
                    HStack(spacing: 3.5) {
                        Text(sourceDisplayName)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.65))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(sourceDisplayName)")
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            if mediaService.isShowingLyrics {
                // MARK: - Lyrics View Mode
                lyricsView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                // MARK: - Standard Player Mode
                VStack(spacing: 12) {
                    // Track Info & Glowing Artwork Row
                    HStack(spacing: 14) {
                        // Album Artwork with Vibrant Ambient Glow Shadow
                        artworkView
                            .frame(width: 54, height: 54)
                        
                        // Track Title & Artist Subtitle
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mediaService.currentTrack.title)
                                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("\(mediaService.currentTrack.artist) • \(sourceDisplayName)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // 3 Neon Pink Animated Equalizer Bars (|||)
                        equalizerBars
                    }
                    .padding(.horizontal, 4)
                    
                    // Progress Scrubber Bar Row
                    HStack(spacing: 8) {
                        Text(mediaService.currentTrack.elapsedFormatted)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 34, alignment: .leading)
                        
                        // Interactive Scrubber with Gradient Track & White Circular Thumb
                        GeometryReader { geo in
                            let fraction = max(0.0, min(1.0, CGFloat(mediaService.currentTrack.progressFraction)))
                            let barWidth = geo.size.width
                            let activeWidth = barWidth * fraction
                            
                            ZStack(alignment: .leading) {
                                // Inactive Track Background
                                Capsule()
                                    .fill(Color.white.opacity(0.18))
                                    .frame(height: 3.5)
                                
                                // Active Played Gradient Track
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.38, blue: 0.52),
                                                Color(red: 1.0, green: 0.65, blue: 0.60)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(barWidth, activeWidth)), height: 3.5)
                                
                                // Circular White Thumb Knob
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: Color.black.opacity(0.4), radius: 2.5, x: 0, y: 1)
                                    .offset(x: max(0, min(barWidth - 10, activeWidth - 5)))
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let targetFraction = max(0.0, min(1.0, Double(value.location.x / barWidth)))
                                        mediaService.seek(to: targetFraction * mediaService.currentTrack.duration)
                                    }
                            )
                        }
                        .frame(height: 14)
                        
                        Text(mediaService.currentTrack.remainingFormatted)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 38, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    
                    // Controls & Volume Row
                    HStack(alignment: .center) {
                        Spacer()
                        
                        // Playback Buttons: 15s Back, Previous, Play/Pause, Next, 15s Forward
                        HStack(spacing: 20) {
                            // Quick Jump 15s Backward
                            Button {
                                mediaService.seekRelative(seconds: -15)
                            } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Jump 15s Backward")
                            
                            // Previous Track Button
                            Button {
                                mediaService.previousTrack()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Previous Track")
                            
                            // Center Play / Pause Glyph Button
                            Button {
                                mediaService.togglePlayPause()
                            } label: {
                                Image(systemName: mediaService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(mediaService.currentTrack.isPlaying ? "Pause" : "Play")
                            
                            // Next Track Button
                            Button {
                                mediaService.nextTrack()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Next Track")
                            
                            // Quick Jump 15s Forward
                            Button {
                                mediaService.seekRelative(seconds: 15)
                            } label: {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Jump 15s Forward")
                        }
                        
                        Spacer()
                        
                        // Functional Volume Control (Mute Toggle + Gradient Slider Line)
                        HStack(spacing: 6) {
                            Button {
                                mediaService.toggleMute()
                            } label: {
                                Image(systemName: volumeIconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 18, height: 18)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(mediaService.currentTrack.volume < 0.03 ? "Unmute Volume" : "Mute Volume")
                            
                            // Interactive Volume Slider Bar
                            GeometryReader { volGeo in
                                let vBarWidth = volGeo.size.width
                                let vFraction = CGFloat(mediaService.currentTrack.volume)
                                
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(height: 3.5)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.38, blue: 0.52),
                                                    Color(red: 1.0, green: 0.65, blue: 0.60)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, min(vBarWidth, vBarWidth * vFraction)), height: 3.5)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { val in
                                            let targetVol = max(0.0, min(1.0, Double(val.location.x / vBarWidth)))
                                            mediaService.setVolume(targetVol)
                                        }
                                )
                            }
                            .frame(width: 65, height: 14)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .onAppear {
            if mediaService.isShowingLyrics {
                mediaService.fetchLyricsIfNeeded()
            }
        }
    }
    
    // MARK: - Synchronized Lyrics View
    private var lyricsView: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background subtle card
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                
                if mediaService.isLyricsLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.35, blue: 0.55)))
                            .scaleEffect(0.9)
                        Text("Loading lyrics...")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mediaService.lyricsLines.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "music.mic")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                        Text(mediaService.lyricsErrorMessage ?? "No lyrics found for \"\(mediaService.currentTrack.title)\"")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Button {
                            mediaService.fetchLyricsIfNeeded()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                Text("Retry")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: mediaService.hasSyncedLyrics ? 12 : 8) {
                                ForEach(Array(mediaService.lyricsLines.enumerated()), id: \.element.id) { index, line in
                                    let isActive = (mediaService.activeLyricIndex == index)
                                    
                                    Button {
                                        if let ts = line.timestamp {
                                            mediaService.seek(to: ts)
                                        }
                                    } label: {
                                        Text(line.text)
                                            .font(.system(
                                                size: mediaService.hasSyncedLyrics ? (isActive ? 15.5 : 13.5) : 13.5,
                                                weight: (mediaService.hasSyncedLyrics && isActive) ? .bold : .medium,
                                                design: .rounded
                                            ))
                                            .foregroundColor(
                                                mediaService.hasSyncedLyrics
                                                    ? (isActive ? .white : .white.opacity(0.38))
                                                    : .white.opacity(0.9)
                                            )
                                            .shadow(
                                                color: (mediaService.hasSyncedLyrics && isActive)
                                                    ? Color(red: 1.0, green: 0.35, blue: 0.6).opacity(0.7)
                                                    : .clear,
                                                radius: 6
                                            )
                                            .scaleEffect((mediaService.hasSyncedLyrics && isActive) ? 1.02 : 1.0, anchor: .leading)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isActive)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: mediaService.activeLyricIndex) { newIndex in
                            if let idx = newIndex, mediaService.hasSyncedLyrics {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(idx, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Mini Bottom Scrubber & Controls
            HStack(spacing: 8) {
                Text(mediaService.currentTrack.elapsedFormatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                
                GeometryReader { geo in
                    let fraction = max(0.0, min(1.0, CGFloat(mediaService.currentTrack.progressFraction)))
                    let barWidth = geo.size.width
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.38, blue: 0.52))
                            .frame(width: max(0, min(barWidth, barWidth * fraction)), height: 3)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let target = max(0.0, min(1.0, Double(val.location.x / barWidth)))
                                mediaService.seek(to: target * mediaService.currentTrack.duration)
                            }
                    )
                }
                .frame(height: 10)
                
                Text(mediaService.currentTrack.remainingFormatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                
                Button {
                    mediaService.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Button {
                    mediaService.togglePlayPause()
                } label: {
                    Image(systemName: mediaService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button {
                    mediaService.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Album Artwork Subview
    @ViewBuilder
    private var artworkView: some View {
        if let data = mediaService.currentTrack.artworkData, let img = NSImage(data: data) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 3)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.28, blue: 0.52),
                                Color(red: 0.90, green: 0.10, blue: 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color(red: 1.0, green: 0.20, blue: 0.45).opacity(0.55), radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Equalizer Bars Subview
    private var equalizerBars: some View {
        let isPlaying = mediaService.currentTrack.isPlaying
        let freqs = mediaService.audioFrequencies
        
        return HStack(alignment: .bottom, spacing: 2.5) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(4.0, (freqs.indices.contains(0) ? freqs[0] : 0.5) * 16.0) : 6.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? freqs.first : 0)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(6.0, (freqs.indices.contains(1) ? freqs[1] : 0.8) * 18.0) : 14.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? (freqs.indices.contains(1) ? freqs[1] : 0) : 0)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(4.0, (freqs.indices.contains(2) ? freqs[2] : 0.6) * 14.0) : 9.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? (freqs.indices.contains(2) ? freqs[2] : 0) : 0)
        }
        .frame(height: 18)
    }
}
