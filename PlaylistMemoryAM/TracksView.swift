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
                            if !tracks.isEmpty {
                                let playCollection: MusicItemCollection<Track>
                                if shuffleEnabledUI {
                                    // Create a shuffled array and wrap it back into a MusicItemCollection for playback
                                    let shuffledArray = Array(tracks).shuffled()
                                    playCollection = MusicItemCollection(shuffledArray)
                                } else {
                                    playCollection = tracks
                                }
                                if let first = playCollection.first {
                                    playerManager.play(track: first, in: playCollection)
                                }
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
                            // Toggle our UI state and, if desired, reshuffle the upcoming queue when starting playback
                            shuffleEnabledUI.toggle()

                            // If you want to immediately apply shuffling to the currently loaded tracks when pressing shuffle,
                            // you can reorder a local copy and start playback. Otherwise, we just reflect the UI state here
                            // and use it when starting playback via the Play button.
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
                            // Cycle local repeat mode UI: none -> all -> one -> none
                            switch repeatModeUI {
                            case .none: repeatModeUI = .all
                            case .all: repeatModeUI = .one
                            case .one: repeatModeUI = .none
                            @unknown default: repeatModeUI = .none
                            }
                        }) {
                            VStack {
                                Image(systemName: repeatModeUI == .one ? "repeat.1" : "repeat")
                                    .font(.system(size: 26))
                                    .foregroundColor(repeatModeUI == .none ? .primary : .green)
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
            // Initialize UI defaults; some MusicKit properties may be unavailable on this platform/version.
            // We keep repeatModeUI purely local to avoid unavailable APIs.
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

