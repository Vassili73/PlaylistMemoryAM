import SwiftUI
import MusicKit
#if canImport(UIKit)
import UIKit
#endif

struct FullPlayerView: View {
    
    @EnvironmentObject var player: MusicPlayerManager
    
    var body: some View {
        VStack(spacing: 24) {
            
            // Cover
            if let artwork = player.currentTrack?.artwork,
               let url = artwork.url(width: 600, height: 600) {
                
                AsyncImage(url: url) { img in
                    img.resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(maxHeight: 320)
                .cornerRadius(12)
                
            } else {
                Color.gray.opacity(0.3)
                    .frame(maxHeight: 320)
                    .cornerRadius(12)
            }
            
            // Titel / Artist
            VStack(spacing: 6) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(player.currentTrack?.artistName ?? "Unbekannter Künstler")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal)
            
            
            // Fortschritt + Zeiten
            VStack(spacing: 8) {
                
                Slider(
                    value: .constant(player.playbackTime),
                    in: 0...max(player.playbackDuration, 1)
                )
                .disabled(true)
                
                HStack {
                    Text(format(time: player.playbackTime))
                        .font(.caption)
                    Spacer()
                    let remaining = max(player.playbackDuration - player.playbackTime, 0)
                    Text("-" + format(time: remaining))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            
            // Shuffle + Previous + Play + Next + Repeat
            HStack(spacing: 40) {
                
                // SHUFFLE BUTTON
                Button {
                    player.shuffleEnabled.toggle()
                    if UserDefaults.standard.bool(forKey: "pm_haptics_enabled") {
                        #if canImport(UIKit)
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        #endif
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title2)
                        .foregroundColor(player.shuffleEnabled ? .green : .primary)
                }
                
                
                // PREVIOUS
                Button {
                    player.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.largeTitle)
                }
                
                
                // PLAY / PAUSE
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                
                
                // NEXT
                Button {
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
                
                
                // REPEAT BUTTON (3-stufig)
                Button {
                    toggleRepeat()
                } label: {
                    Image(systemName: repeatIcon())
                        .font(.title2)
                        .foregroundColor(player.repeatMode == .off ? .primary : .green)
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
    }
    
    
    // MARK: - Repeat Symbol abhängig vom Modus
    private func repeatIcon() -> String {
        switch player.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
    
    // MARK: - Toggle Repeat Mode (off -> all -> one -> off)
    private func toggleRepeat() {
        switch player.repeatMode {
        case .off:
            player.repeatMode = .all
        case .all:
            player.repeatMode = .one
        case .one:
            player.repeatMode = .off
        }
        if UserDefaults.standard.bool(forKey: "pm_haptics_enabled") {
            #if canImport(UIKit)
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            #endif
        }
    }
    
    
    // MARK: - Zeitformat mm:ss
    private func format(time: TimeInterval) -> String {
        let totalSeconds = Int(time.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

