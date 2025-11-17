import SwiftUI
import MusicKit

struct LastHeardCard: View {
    @EnvironmentObject var player: MusicPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Artwork (nur wenn aktuell ein Track läuft)
                if let track = player.currentTrack, let artwork = track.artwork, let url = artwork.url(width: 200, height: 200) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Color.gray.opacity(0.2)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zuletzt gehört")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(player.currentTrack?.title ?? "Fortsetzen")
                        .font(.headline)
                        .lineLimit(1)

                    Text(player.currentTrack != nil ? (player.currentTrack?.albumTitle ?? "Album") : (player.lastPlaylistName ?? "Playlist"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if player.currentTrack == nil {
                        player.resumeLastPlayback()
                    } else {
                        player.togglePlayPause()
                    }
                } label: {
                    Image(systemName: player.currentTrack == nil ? "play.fill" : (player.isPlaying ? "pause.fill" : "play.fill"))
                        .font(.title3.weight(.semibold))
                        .padding(10)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .accessibilityLabel("Fortsetzen")
            }

            if player.currentTrack != nil {
                ProgressView(value: player.playbackTime, total: max(player.playbackDuration, 1))
                    .tint(.accentColor)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 2, y: 1)
        .padding(.horizontal)
    }
}

struct ContentView: View {
    
    @StateObject private var musicAuth = MusicAuthManager()
    @StateObject private var player = MusicPlayerManager.shared
    
    @State private var playlists: MusicItemCollection<Playlist> = []
    @State private var showLoadedToast = false

    @State private var searchText: String = ""
    @State private var recentSearches: [String] = []
    
    private var filteredPlaylists: MusicItemCollection<Playlist> {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return playlists
        }
        let lower = searchText.lowercased()
        let filtered = Array(playlists).filter { $0.name.lowercased().contains(lower) }
        return MusicItemCollection(filtered)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            NavigationView {
                VStack(spacing: 20) {
                    
                    // Zuletzt gehört Card (sichtbar, sobald ein Track aktiv ist)
                    LastHeardCard()
                        .environmentObject(player)
                    
                    if !musicAuth.isAuthorized {
                        Button("Apple Music verbinden") {
                            Task { await musicAuth.requestAuthorization() }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        // Optional: Show a subtle status or nothing at all when authorized
                        EmptyView()
                    }
                    
                    if playlists.isEmpty {
                        Button("Playlists laden") {
                            Task { await loadPlaylists() }
                        }
                        .disabled(!musicAuth.isAuthorized)
                    }
                    
                    List(filteredPlaylists, id: \.id) { playlist in
                        NavigationLink(
                            destination: TracksView(playlist: playlist)
                                .environmentObject(player)
                        ) {
                            HStack(spacing: 15) {
                                
                                if let url = playlist.artwork?.url(width: 200, height: 200) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.2)
                                    }
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                } else {
                                    Color.gray.opacity(0.3)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                }
                                
                                Text(playlist.name)
                                    .font(.headline)
                            }
                        }
                    }
                    .navigationTitle("PlaylistMemory AM")
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Playlists") {
                        // Suggestions from recent searches
                        ForEach(recentSearches, id: \.self) { term in
                            Text(term).searchCompletion(term)
                        }
                    }
                    .onSubmit(of: .search) {
                        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !term.isEmpty else { return }
                        if !recentSearches.contains(term) {
                            recentSearches.insert(term, at: 0)
                            if recentSearches.count > 8 { recentSearches.removeLast(recentSearches.count - 8) }
                        }
                    }
                    .onChange(of: searchText) { _, newValue in
                        // Optionally, we could live-update suggestions or debounce; no-op for now
                    }
                    .task {
                        if musicAuth.isAuthorized && playlists.isEmpty {
                            await loadPlaylists()
                        }
                    }
                    .onChange(of: musicAuth.isAuthorized) { _, newValue in
                        if newValue {
                            Task { await loadPlaylists() }
                        }
                    }
                    
                    if !searchText.isEmpty && filteredPlaylists.isEmpty {
                        Text("No playlists found for \"\(searchText)\"")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            
            // 🔥 Mini Player — immer ganz unten sichtbar
            MiniPlayerView()
                .environmentObject(player)
                .frame(height: player.currentTrack == nil ? 0 : 70)
                .animation(.easeInOut, value: player.currentTrack)
            
            if showLoadedToast {
                Text("Playlists geladen")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 3)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $player.isShowingFullPlayer) {
            FullPlayerView()
                .environmentObject(player)
        }
    }
    
    func loadPlaylists() async {
        do {
            let req = MusicLibraryRequest<Playlist>()
            let res = try await req.response()
            playlists = res.items
            showLoadedToast = !playlists.isEmpty
            if showLoadedToast {
                // Auto-hide after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showLoadedToast = false
                }
            }
        } catch {
            print("❌ Fehler beim Laden:", error)
        }
    }
}

#Preview {
    ContentView()
}
