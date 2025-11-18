import SwiftUI
import MusicKit

struct LastHeardCard: View {
    @EnvironmentObject var player: MusicPlayerManager

    @State private var lastTitle: String? = nil
    @State private var lastAlbum: String? = nil
    @State private var lastArtworkURL: URL? = nil
    @State private var lastPlaylist: String? = nil

    private func loadLastSavedInfoIfNeeded() {
        // If we already have a current track, no need
        if player.currentTrack != nil { return }
        // Retrieve stored playlist ID
        let pidRaw = UserDefaults.standard.string(forKey: "pm_last_playlist_id")
        guard let pidRaw else { return }
        let pid = MusicItemID(pidRaw)
        Task {
            do {
                // Try to fetch the playlist from library with tracks (lightweight)
                var libRequest = MusicLibraryRequest<Playlist>()
                libRequest.filter(matching: \Playlist.LibraryFilter.id, equalTo: pid)
                let libResponse = try await libRequest.response()
                guard var pl = libResponse.items.first else { return }
                pl = try await pl.with([.tracks])
                let playlistName = pl.name
                guard let tracks = pl.tracks else { return }
                let collection = MusicItemCollection(tracks)
                // Read saved index from the same memory scheme as the player
                if let idx = player.getSavedIndex(for: collection), collection.indices.contains(idx) {
                    let t = collection[idx]
                    await MainActor.run {
                        self.lastTitle = t.title
                        self.lastAlbum = t.albumTitle
                        self.lastArtworkURL = t.artwork?.url(width: 200, height: 200)
                        self.lastPlaylist = playlistName
                    }
                }
            } catch {
                // Silent fail – keep placeholder UI
            }
        }
    }

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
                } else if let url = lastArtworkURL {
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

                    Text(player.currentTrack?.title ?? lastTitle ?? "Fortsetzen")
                        .font(.headline)
                        .lineLimit(1)

                    Text(
                        player.currentTrack != nil
                        ? (player.lastPlaylistName ?? "Playlist")
                        : (lastPlaylist ?? player.lastPlaylistName ?? "Playlist")
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Button {
                    if player.currentTrack == nil {
                        // Load last playlist/tracks and start playback from stored state
                        player.resumeFromStoredPlaylist()
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
        .onAppear { loadLastSavedInfoIfNeeded() }
        .onChange(of: player.currentTrack) { _, _ in
            loadLastSavedInfoIfNeeded()
        }
    }
}

struct ContentView: View {
    
    @StateObject private var musicAuth = MusicAuthManager()
    @StateObject private var player = MusicPlayerManager.shared
    
    @State private var playlists: MusicItemCollection<Playlist> = []
    @State private var showLoadedToast = false
    
    @State private var searchText: String = ""
    @State private var recentSearches: [String] = []
    
    @State private var showSettings = false
    @State private var autoResumeEnabled: Bool = UserDefaults.standard.bool(forKey: "pm_auto_resume_enabled")
    @State private var autoResumeOnOpenPlaylist: Bool = UserDefaults.standard.bool(forKey: "pm_auto_resume_on_open_playlist")
    @State private var restoreLastPosition: Bool = UserDefaults.standard.bool(forKey: "pm_restore_last_position")
    @State private var hapticsEnabled: Bool = UserDefaults.standard.bool(forKey: "pm_haptics_enabled")
    
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
                    .padding(.bottom, player.currentTrack == nil ? 0 : 12)
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("Settings")
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        NavigationView {
                            Form {
                                Section(header: Text("Playback")) {
                                    Toggle("Automatisch fortsetzen beim App-Start", isOn: Binding(
                                        get: { autoResumeEnabled },
                                        set: { newValue in
                                            autoResumeEnabled = newValue
                                            UserDefaults.standard.set(newValue, forKey: "pm_auto_resume_enabled")
                                        }
                                    ))
                                    Toggle("Automatisch fortsetzen beim Öffnen der Playlist", isOn: Binding(
                                        get: { autoResumeOnOpenPlaylist },
                                        set: { newValue in
                                            autoResumeOnOpenPlaylist = newValue
                                            UserDefaults.standard.set(newValue, forKey: "pm_auto_resume_on_open_playlist")
                                        }
                                    ))
                                    Toggle("Letzte Position wiederherstellen", isOn: Binding(
                                        get: { restoreLastPosition },
                                        set: { newValue in
                                            restoreLastPosition = newValue
                                            UserDefaults.standard.set(newValue, forKey: "pm_restore_last_position")
                                        }
                                    ))
                                }
                                Section(header: Text("Feedback")) {
                                    Toggle("Haptisches Feedback bei Steuerung", isOn: Binding(
                                        get: { hapticsEnabled },
                                        set: { newValue in
                                            hapticsEnabled = newValue
                                            UserDefaults.standard.set(newValue, forKey: "pm_haptics_enabled")
                                        }
                                    ))
                                }
                                Section(header: Text("Speicher")) {
                                    Button(role: .destructive) {
                                        // Clear last played memory and playlist id
                                        UserDefaults.standard.removeObject(forKey: "pm_last_playlist_id")
                                        // Also clear any per-playlist memory keys by brute-force if desired (skipped here)
                                    } label: {
                                        Text("\"Zuletzt gespielt\" zurücksetzen")
                                    }
                                    Button(role: .destructive) {
                                        // Clear recent searches
                                        recentSearches = []
                                        // Persist an empty array if you store it in UserDefaults elsewhere (not currently persisted beyond runtime)
                                    } label: {
                                        Text("Suchverlauf löschen")
                                    }
                                }
                            }
                            .navigationTitle("Einstellungen")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Fertig") { showSettings = false }
                                }
                            }
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
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: player.currentTrack == nil ? 0 : 64)
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
