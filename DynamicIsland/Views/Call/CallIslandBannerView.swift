import SwiftUI
import AppKit

public struct CallIslandBannerView: View {
    @ObservedObject public var viewModel: NotchViewModel
    public let call: ActiveCallSession
    
    public init(viewModel: NotchViewModel, call: ActiveCallSession) {
        self.viewModel = viewModel
        self.call = call
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Ear Bar: Ambient Indicators Beside the Hardware Camera Notch
            HStack(spacing: 0) {
                // Left Ear: App Identifier Badge & Icon
                HStack(spacing: 4.5) {
                    Image(systemName: call.category.appType.iconName)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(call.category.appType.accentColor)
                    Text(call.category.appType.rawValue.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.leading, 14)
                
                Spacer()
                
                // Hardware Camera Notch Clearance (guarantees zero UI hidden behind the notch)
                Color.clear
                    .frame(width: viewModel.physicalNotchWidth)
                
                Spacer()
                
                // Right Ear: Call State Dot & Title
                HStack(spacing: 4.5) {
                    Circle()
                        .fill(call.status == .incoming ? Color.yellow : (call.status == .active ? Color.green : Color.red))
                        .frame(width: 5, height: 5)
                    Text(call.status == .incoming ? "RINGING" : (call.status == .active ? "LIVE" : "ENDED"))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.trailing, 14)
            }
            .frame(height: viewModel.physicalNotchHeight)
            
            // MARK: - Bottom Call Content Row (100% Unobstructed Below Physical Camera Notch)
            HStack(spacing: 12) {
                // Left: Caller Avatar & Service Badge
                avatarView
                
                // Center: Caller Info & Live Status
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(call.contact.name)
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if call.status == .active {
                            // Live Audio Indicator
                            HStack(alignment: .bottom, spacing: 1.5) {
                                ForEach(0..<4, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(call.category.appType.accentColor)
                                        .frame(width: 2.2, height: max(3.0, viewModel.callService.callAudioFrequencies[i] * 12))
                                }
                            }
                            .frame(height: 12)
                        }
                    }
                    
                    HStack(spacing: 5) {
                        if call.status == .incoming {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(call.category.appType.accentColor)
                                    .frame(width: 5, height: 5)
                                Text(call.category.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(call.category.appType.accentColor)
                                
                                if !call.contact.numberOrHandle.isEmpty && call.contact.numberOrHandle != call.contact.name {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 9))
                                    Text(call.contact.numberOrHandle)
                                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.65))
                                        .lineLimit(1)
                                }
                            }
                        } else if call.status == .active {
                            Text(call.durationFormatted)
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 9))
                            
                            Text(call.category.rawValue)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text("Call Ended")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // Right: Action Buttons (Decline / Accept / Controls)
                HStack(spacing: 8) {
                    if call.status == .incoming {
                        // Decline (Red)
                        Button {
                            viewModel.callService.declineCall()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Decline Call")
                        
                        // Accept (Green)
                        Button {
                            viewModel.callService.answerCall()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(call.category.appType.accentColor)
                                    .frame(width: 34, height: 34)
                                Image(systemName: call.category.isVideo ? "video.fill" : "phone.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Answer Call")
                    } else if call.status == .active {
                        // Mute Toggle Button
                        Button {
                            viewModel.callService.toggleMute()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(call.isMuted ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Image(systemName: call.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(call.isMuted ? .red : .white.opacity(0.85))
                            }
                        }
                        .buttonStyle(.plain)
                        .help(call.isMuted ? "Unmute Microphone" : "Mute Microphone")
                        
                        // Speaker Button
                        Button {
                            viewModel.callService.toggleSpeaker()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(call.isSpeaker ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Image(systemName: call.isSpeaker ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(call.isSpeaker ? .cyan : .white.opacity(0.85))
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Speaker Output")
                        
                        // End Call (Red)
                        Button {
                            viewModel.callService.endCall()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("End Call")
                    } else {
                        // Ended indicator
                        Image(systemName: "phone.down.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14, weight: .bold))
                            .padding(.trailing, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Avatar & App Badge
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let data = call.contact.avatarImageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                    .shadow(color: Color(hex: call.contact.avatarColorHex).opacity(0.4), radius: 3)
            } else {
                ZStack {
                    Circle()
                        .fill(Color(hex: call.contact.avatarColorHex))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color(hex: call.contact.avatarColorHex).opacity(0.4), radius: 3)
                    
                    Text(call.contact.initials)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            // App Badge: Phone or WhatsApp Icon
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 17, height: 17)
                
                Circle()
                    .fill(call.category.appType.accentColor)
                    .frame(width: 14, height: 14)
                
                Image(systemName: call.category.appType.iconName)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: 2, y: 2)
        }
    }
}
