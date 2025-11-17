import SwiftUI
import MusicKit

struct MiniPlayerView: View {
    
    @EnvironmentObject var playerManager: MusicPlayerManager
    
    var body: some View {
        if let track = playerManager.currentTrack {
            VStack(spacing: 4) {
                
                // 🔵 Fortschrittsbalken (Mini)
                ProgressView(value: playerManager.playbackTime,
                             total: max(playerManager.playbackDuration, 1))
                    .accentColor(.blue)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    
                    // COVER
                    if let artwork = track.artwork,
                       let url = artwork.url(width: 100, height: 100) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                    }
                    
                    // TITLE + ARTIST
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(track.artistName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // ▶️ / ⏸
                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    
                    // ⏭ Next
                    Button {
                        playerManager.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    playerManager.isShowingFullPlayer = true
                }
            }
            .background(.ultraThinMaterial)
        }
    }
}
