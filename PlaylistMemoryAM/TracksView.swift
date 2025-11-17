import SwiftUI
import MusicKit

struct TracksView: View {
    
    let playlist: Playlist
    @EnvironmentObject var player: MusicPlayerManager
    
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            
            if let artwork = playlist.artwork,
               let url = artwork.url(width: 500, height: 500) {
                
                VStack(spacing: 12) {
                    
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    .padding(.top)
                    
                    Text(playlist.name)
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 30) {
                        
                        Button {
                            if let first = tracks.first {
                                player.play(track: first, in: tracks)
                            }
                        } label: {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                Text("Play")
                                    .font(.caption)
                            }
                        }
                        
                        Button { player.toggleShuffle() } label: {
                            VStack {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 26))
                                    .foregroundColor(player.shuffleEnabled ? .green : .primary)
                                Text("Shuffle")
                                    .font(.caption)
                            }
                        }
                        
                        Button { player.toggleRepeat() } label: {
                            VStack {
                                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                    .font(.system(size: 26))
                                    .foregroundColor(player.repeatMode == .off ? .primary : .green)
                                Text("Repeat")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            
            
            Group {
                if isLoading {
                    ProgressView("Lade Songs…")
                        .padding()
                } else {
                    List(tracks, id: \.id) { track in
                        
                        HStack(spacing: 15) {
                            if let artwork = track.artwork,
                               let url = artwork.url(width: 120, height: 120) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(track.title)
                                    .font(.headline)
                                Text(track.artistName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.play(track: track, in: tracks)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTracks() }
    }
    
    
    // MARK: - LOAD
    func loadTracks() async {
        do {
            let full = try await playlist.with([.tracks])
            
            if let loaded = full.tracks {
                tracks = loaded
            }
            
            isLoading = false
            
            // 🔥 gespeicherter Index?
            if let saved = player.getSavedIndex(for: tracks),
               tracks.indices.contains(saved) {
                let track = tracks[saved]
                player.play(track: track, in: tracks)
            }
            
        } catch {
            print("❌ Fehler beim Laden:", error)
            isLoading = false
        }
    }
}
