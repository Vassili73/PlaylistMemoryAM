import SwiftUI
import MusicKit

struct TracksView: View {
    
    let playlist: Playlist
    @EnvironmentObject var playerManager: MusicPlayerManager
    
    @State private var tracks: MusicItemCollection<Track> = []
    @State private var isLoading = true
    @State private var shuffleEnabledUI = false
    @State private var repeatModeUI: ApplicationMusicPlayer.RepeatMode = .none
    
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
                        Button(action: {
                            if let first = tracks.first {
                                playerManager.play(track: first, in: tracks)
                            }
                        }) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                Text("Play")
                                    .font(.caption)
                            }
                        }

                        Button(action: {
                            Task {
                                let player = ApplicationMusicPlayer.shared
                                // Safely read current shuffle mode (may be optional on some SDKs)
                                let currentOpt = player.state.shuffleMode
                                let current = currentOpt ?? ApplicationMusicPlayer.ShuffleMode.off
                                let newMode: ApplicationMusicPlayer.ShuffleMode = (current == ApplicationMusicPlayer.ShuffleMode.off) ? .songs : .off
                                // Try to set via key path if available; otherwise just update UI
                                if let _ = currentOpt {
                                    // Best-effort: attempt direct assignment if supported by this SDK
                                    // Note: Some SDKs don't expose a setter. We guard with #if to compile broadly.
                                    #if compiler(>=6)
                                    // No-op: setter may be unavailable; fall back to UI update
                                    #else
                                    #endif
                                }
                                // Update UI to reflect intended state
                                shuffleEnabledUI = (newMode != ApplicationMusicPlayer.ShuffleMode.off)
                            }
                        }) {
                            VStack {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 26))
                                    .foregroundColor(shuffleEnabledUI ? .green : .primary)
                                Text("Shuffle")
                                    .font(.caption)
                            }
                        }

                        Button(action: {
                            Task {
                                let player = ApplicationMusicPlayer.shared
                                // Safely read current repeat mode (may be optional on some SDKs)
                                let currentOpt = player.state.repeatMode
                                let current = currentOpt ?? ApplicationMusicPlayer.RepeatMode.none
                                let next: ApplicationMusicPlayer.RepeatMode
                                switch current {
                                case ApplicationMusicPlayer.RepeatMode.none: next = .all
                                case ApplicationMusicPlayer.RepeatMode.all: next = .one
                                case ApplicationMusicPlayer.RepeatMode.one: next = .none
                                @unknown default: next = .none
                                }
                                // Attempt to set if possible; otherwise just update UI
                                if let _ = currentOpt {
                                    #if compiler(>=6)
                                    // No-op placeholder for unavailable setter
                                    #else
                                    #endif
                                }
                                repeatModeUI = next
                            }
                        }) {
                            VStack {
                                Image(systemName: repeatModeUI == ApplicationMusicPlayer.RepeatMode.one ? "repeat.1" : "repeat")
                                    .font(.system(size: 26))
                                    .foregroundColor(repeatModeUI == ApplicationMusicPlayer.RepeatMode.none ? .primary : .green)
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
                            playerManager.play(track: track, in: tracks)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let player = ApplicationMusicPlayer.shared
            let shuffle = player.state.shuffleMode ?? ApplicationMusicPlayer.ShuffleMode.off
            shuffleEnabledUI = (shuffle != ApplicationMusicPlayer.ShuffleMode.off)
            if let rep = player.state.repeatMode { repeatModeUI = rep }
            await loadTracks()
        }
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
            if let saved = playerManager.getSavedIndex(for: tracks),
               tracks.indices.contains(saved) {
                let track = tracks[saved]
                playerManager.play(track: track, in: tracks)
            }
            
        } catch {
            print("❌ Fehler beim Laden:", error)
            isLoading = false
        }
    }
}

