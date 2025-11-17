import Foundation
import MusicKit
import Combine

// 🔁 Eigene Repeat-Optionen
enum RepeatMode {
    case off
    case all
    case one
}

@MainActor
class MusicPlayerManager: ObservableObject {
    
    static let shared = MusicPlayerManager()
    
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var isShowingFullPlayer = false
    
    // Fortschritt
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 1
    
    // Shuffle/Repeat
    @Published var shuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    @Published var lastPlaylistName: String? = nil
    @Published var lastMemoryKey: String? = nil
    private let lastPlaylistIDKey = "pm_last_playlist_id"
    
    private let player = ApplicationMusicPlayer.shared
    
    private var playlist: MusicItemCollection<Track> = []
    private var index: Int = 0
    
    private var timer: Timer?
    private var stateObserver: AnyCancellable?
    
    private init() {
        // Periodically sync from ApplicationMusicPlayer state
        stateObserver = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Sync playback time from system player
                self.playbackTime = self.player.playbackTime
                // Sync playing status if possible
                let status = self.player.state.playbackStatus
                self.isPlaying = (status == .playing)
            }
    }
    
    
    // MARK: - Speicher-Schlüssel (nur über erste Track-ID)
    private func memoryKey(for playlist: MusicItemCollection<Track>) -> String {
        guard let first = playlist.first else { return "playlist_unknown" }
        return "playlist_\(first.id.rawValue)"
    }
    
    // Allow external views (e.g., TracksView) to provide a stable playlist identifier for resume
    func setCurrentPlaylistID(_ id: MusicItemID) {
        UserDefaults.standard.set(id.rawValue, forKey: lastPlaylistIDKey)
    }
    
    
    // MARK: - Track in Playlist spielen (mit Memory)
    func play(track: Track, in playlist: MusicItemCollection<Track>) {
        
        // Wenn es dieselbe Playlist ist → nicht komplett neu setzen
        if !self.playlist.isEmpty,
           self.playlist.map({ $0.id }) == playlist.map({ $0.id }) {
            
            if let idx = playlist.firstIndex(of: track) {
                index = idx
                playIndex(index)
                saveMemory()
                return
            }
        }
        
        // Neue Playlist
        self.playlist = playlist
        
        // Versuch, einen Playlist-Namen zu bestimmen (falls verfügbar) – als Fallback nur "Playlist"
        if let albumTitle = playlist.first?.albumTitle, !albumTitle.isEmpty {
            lastPlaylistName = albumTitle
        } else {
            lastPlaylistName = "Playlist"
        }
        
        if let idx = playlist.firstIndex(of: track) {
            index = idx
        } else {
            index = 0
        }
        
        playIndex(index)
        saveMemory()
    }
    
    
    // MARK: - Index spielen
    private func playIndex(_ idx: Int) {
        guard playlist.indices.contains(idx) else { return }

        let items = Array(playlist)
        Task {
            do {
                // Set full queue
                player.queue = ApplicationMusicPlayer.Queue(for: items)
                // Start playback
                try await player.play()

                // Try to move to requested index by skipping forward
                // If API to jump by index is unavailable, perform sequential skips
                if idx > 0 {
                    for _ in 0..<idx { try? await player.skipToNextEntry() }
                }

                // Update UI state
                let track = items[idx]
                currentTrack = track
                isPlaying = true
                startProgress(for: track)
                saveMemory()
            } catch {
                print("❌ Fehler beim Abspielen:", error)
            }
        }
    }
    
    
    // MARK: - Nächster Track
    func nextTrack() {
        Task {
            do {
                try await player.skipToNextEntry()
                // Reflect state optimistically
                isPlaying = true
                // Advance local index if possible
                if index < max(playlist.count - 1, 0) { index += 1 }
                if playlist.indices.contains(index) { currentTrack = playlist[index] }
                saveMemory()
            } catch {
                print("❌ Fehler Next:", error)
            }
        }
    }
    
    
    // MARK: - Vorheriger Track
    func previousTrack() {
        Task {
            do {
                try await player.skipToPreviousEntry()
                isPlaying = true
                if index > 0 { index -= 1 }
                if playlist.indices.contains(index) { currentTrack = playlist[index] }
                saveMemory()
            } catch {
                print("❌ Fehler Previous:", error)
            }
        }
    }
    
    
    // MARK: - Play / Pause
    func togglePlayPause() {
        Task {
            if isPlaying {
                try? await player.pause()
                isPlaying = false
            } else {
                try? await player.play()
                isPlaying = true
            }
            let status = player.state.playbackStatus
            isPlaying = (status == .playing)
        }
    }
    
    func seek(to time: TimeInterval) {
        // Clamp to valid range
        let duration = max(self.playbackDuration, 0)
        let clamped = max(0, min(time, duration))

        // ApplicationMusicPlayer does not expose seek(to:), set playbackTime directly
        self.player.playbackTime = clamped

        // Keep our published state in sync for the UI
        self.playbackTime = clamped
    }
    
    
    // MARK: - Fortschritt (simuliert, nur für Anzeige)
    private func startProgress(for track: Track) {
        timer?.invalidate()
        
        playbackDuration = max(track.duration ?? 0, 1)
        playbackTime = 0   // immer bei 0 starten
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5,
                                     repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isPlaying else { return }
            
            self.playbackTime += 0.5
            
            if self.playbackTime >= self.playbackDuration {
                self.playbackTime = self.playbackDuration
                
                // Auto-Weiterlogik
                switch self.repeatMode {
                case .one:
                    self.playIndex(self.index)
                case .all:
                    self.nextTrack()
                case .off:
                    if self.index < self.playlist.count - 1 {
                        self.nextTrack()
                    } else {
                        self.isPlaying = false
                    }
                }
            }
            
            self.saveMemory()
        }
    }
    
    
    // MARK: - Memory speichern (pro Playlist nur Index)
    func saveMemory() {
        guard !playlist.isEmpty else { return }
        
        let key = memoryKey(for: playlist)
        
        lastMemoryKey = key
        let mem: [String: Any] = [
            "index": index,
            "playlistName": lastPlaylistName ?? "Playlist",
            "position": playbackTime
        ]
        
        UserDefaults.standard.set(mem, forKey: key)
    }
    
    
    // MARK: - Gespeicherten Index für Playlist holen
    func getSavedIndex(for playlist: MusicItemCollection<Track>) -> Int? {
        let key = memoryKey(for: playlist)
        
        guard let data = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        return data["index"] as? Int
    }
    
    func getSavedPosition(for playlist: MusicItemCollection<Track>) -> TimeInterval? {
        let key = memoryKey(for: playlist)
        guard let data = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        return data["position"] as? TimeInterval
    }
    
    // MARK: - Memory lesen (roh)
    private func getSavedMemory(forKey key: String) -> [String: Any]? {
        return UserDefaults.standard.dictionary(forKey: key)
    }
    
    // MARK: - Resume by loading stored playlist and tracks
    func resumeFromStoredPlaylist() {
        // If we already have a playlist loaded, fall back to existing resume
        if !playlist.isEmpty { resumeLastPlayback(); return }
        guard let raw = UserDefaults.standard.string(forKey: lastPlaylistIDKey) else { return }
        let pid = MusicItemID(raw)
        Task {
            do {
                // Try fetching from the user's library by ID
                var libRequest = MusicLibraryRequest<Playlist>()
                libRequest.filter(matching: \Playlist.LibraryFilter.id, equalTo: pid)
                let libResponse = try await libRequest.response()
                guard var playlist = libResponse.items.first else { return }

                playlist = try await playlist.with([.tracks])
                guard let tracks = playlist.tracks else { return }

                let collection = MusicItemCollection(tracks)
                self.playlist = collection
                if let albumTitle = collection.first?.albumTitle, !albumTitle.isEmpty {
                    self.lastPlaylistName = albumTitle
                } else {
                    self.lastPlaylistName = "Playlist"
                }

                let savedIndex = self.getSavedIndex(for: collection) ?? 0
                let idx = collection.indices.contains(savedIndex) ? savedIndex : 0
                self.playIndex(idx)

                if let pos = self.getSavedPosition(for: collection), pos > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.seek(to: pos)
                    }
                }
            } catch {
                print("❌ Fehler beim Resume aus Playlist:", error)
            }
        }
    }

    // MARK: - Resume letzte Wiedergabe
    func resumeLastPlayback() {
        // Wenn wir bereits spielen, einfach toggeln
        if currentTrack != nil {
            togglePlayPause()
            return
        }

        // Falls wir kürzlich gespeichert haben, nutze lastMemoryKey
        // In neuen Flow könnte man auch resumeFromStoredPlaylist() verwenden, falls keine Playlist geladen ist.
        guard let key = lastMemoryKey ?? (playlist.isEmpty ? nil : memoryKey(for: playlist)) else {
            // Kein Key verfügbar → nichts zu tun
            return
        }
        guard let mem = getSavedMemory(forKey: key) else { return }

        // Index laden
        let savedIndex = mem["index"] as? Int ?? 0
        let savedName = mem["playlistName"] as? String
        self.lastPlaylistName = savedName

        // Wir haben hier keine persistente Playlist-ID in deinem aktuellen Modell.
        // Workaround: Wenn aktuell keine Playlist im Manager ist, können wir nicht laden.
        // In deinem Flow wird die Playlist beim Öffnen von TracksView geladen –
        // daher versuchen wir nur fortzusetzen, wenn noch eine Playlist im Speicher liegt.
        guard !playlist.isEmpty else {
            // Ohne geladene Playlist können wir hier nicht automatisch fortsetzen.
            // UI kann ggf. den Nutzer zur Playlist führen.
            return
        }

        // Index bounds check
        let idx = playlist.indices.contains(savedIndex) ? savedIndex : 0
        playIndex(idx)

        // Restore position if available
        if let pos = mem["position"] as? TimeInterval, pos > 0 {
            // Give the player a brief moment to start, then seek
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.seek(to: pos)
            }
        }

        saveMemory()
    }
}

