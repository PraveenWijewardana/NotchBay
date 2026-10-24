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
        VStack(spacing: 14) {
            // MARK: - 1. Top Header Row (Now Playing & Source App Link)
            HStack(alignment: .center) {
                Text("Now Playing")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    mediaService.openSourceApp()
                } label: {
                    HStack(spacing: 3.5) {
                        Text(sourceDisplayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.65))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(sourceDisplayName)")
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            // MARK: - 2. Track Info & Glowing Artwork Row
            HStack(spacing: 14) {
                // Album Artwork with Vibrant Ambient Glow Shadow
                artworkView
                    .frame(width: 56, height: 56)
                
                // Track Title & Artist Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(mediaService.currentTrack.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(mediaService.currentTrack.artist) • \(sourceDisplayName)")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // 3 Neon Pink Animated Equalizer Bars (|||)
                equalizerBars
            }
            .padding(.horizontal, 4)
            
            // MARK: - 3. Progress Scrubber Bar Row
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
            
            // MARK: - 4. Controls & Volume Row
            HStack(alignment: .center) {
                Spacer()
                
                // Playback Buttons: Previous, Play/Pause, Next
                HStack(spacing: 28) {
                    // Previous Track Button
                    Button {
                        mediaService.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Previous Track")
                    
                    // Center Play / Pause Glyph Button (Solid, Large, No Circle)
                    Button {
                        mediaService.togglePlayPause()
                    } label: {
                        Image(systemName: mediaService.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(mediaService.currentTrack.isPlaying ? "Pause" : "Play")
                    
                    // Next Track Button
                    Button {
                        mediaService.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Next Track")
                }
                
                Spacer()
                
                // Functional Volume Control (Mute Toggle + Gradient Slider Line)
                HStack(spacing: 6) {
                    Button {
                        mediaService.toggleMute()
                    } label: {
                        Image(systemName: volumeIconName)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Mute")
                    
                    GeometryReader { geo in
                        let vol = max(0.0, min(1.0, CGFloat(mediaService.currentTrack.volume)))
                        let width = geo.size.width
                        let activeVolWidth = width * vol
                        
                        ZStack(alignment: .leading) {
                            // Inactive Volume Line
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 3.5)
                            
                            // Active Volume Gradient Line
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
                                .frame(width: max(0, min(width, activeVolWidth)), height: 3.5)
                            
                            // White Thumb Knob
                            Circle()
                                .fill(Color.white)
                                .frame(width: 9, height: 9)
                                .shadow(color: Color.black.opacity(0.35), radius: 2)
                                .offset(x: max(0, min(width - 9, activeVolWidth - 4.5)))
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0.0, min(1.0, Double(value.location.x / width)))
                                    mediaService.setVolume(fraction)
                                }
                        )
                    }
                    .frame(width: 76, height: 16)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Artwork Subview with Ambient Glow
    private var artworkView: some View {
        Group {
            if let data = mediaService.currentTrack.artworkData,
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.20, blue: 0.45).opacity(0.45), radius: 10, x: 0, y: 4)
            } else {
                // Vibrant Fallback Artwork (matching the pink/neon graffiti style in reference)
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.22, blue: 0.50),
                                    Color(red: 0.90, green: 0.10, blue: 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    // Stylized Graphic Overlay
                    VStack(spacing: 2) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(red: 1.0, green: 0.20, blue: 0.45).opacity(0.55), radius: 10, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Equalizer Bars Subview
    private var equalizerBars: some View {
        let isPlaying = mediaService.currentTrack.isPlaying
        let freqs = mediaService.audioFrequencies
        
        return HStack(alignment: .bottom, spacing: 2.5) {
            // Bar 1
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(4.0, (freqs.indices.contains(0) ? freqs[0] : 0.5) * 16.0) : 6.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? freqs.first : 0)
            
            // Bar 2
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(6.0, (freqs.indices.contains(1) ? freqs[1] : 0.8) * 18.0) : 14.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? (freqs.indices.contains(1) ? freqs[1] : 0) : 0)
            
            // Bar 3
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 1.0, green: 0.32, blue: 0.52))
                .frame(width: 3.5, height: isPlaying ? max(4.0, (freqs.indices.contains(2) ? freqs[2] : 0.6) * 14.0) : 9.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPlaying ? (freqs.indices.contains(2) ? freqs[2] : 0) : 0)
        }
        .frame(height: 18)
    }
}
