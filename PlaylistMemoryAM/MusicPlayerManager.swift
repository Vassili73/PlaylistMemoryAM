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
    
    private let player = ApplicationMusicPlayer.shared
    
    private var playlist: MusicItemCollection<Track> = []
    private var index: Int = 0
    
    private var timer: Timer?
    
    private init() {}
    
    
    // MARK: - Speicher-Schlüssel (nur über erste Track-ID)
    private func memoryKey(for playlist: MusicItemCollection<Track>) -> String {
        guard let first = playlist.first else { return "playlist_unknown" }
        return "playlist_\(first.id.rawValue)"
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
        
        let track = playlist[idx]
        
        Task {
            do {
                player.queue = ApplicationMusicPlayer.Queue(for: [track])
                try await player.play()
                
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
        guard !playlist.isEmpty else { return }
        
        if repeatMode == .one {
            playIndex(index)
            return
        }
        
        index += 1
        
        if index >= playlist.count {
            if repeatMode == .all {
                index = 0
            } else {
                index = playlist.count - 1
                return
            }
        }
        
        playIndex(index)
        saveMemory()
    }
    
    
    // MARK: - Vorheriger Track
    func previousTrack() {
        guard !playlist.isEmpty else { return }
        
        if repeatMode == .one {
            playIndex(index)
            return
        }
        
        index -= 1
        
        if index < 0 {
            if repeatMode == .all {
                index = playlist.count - 1
            } else {
                index = 0
                return
            }
        }
        
        playIndex(index)
        saveMemory()
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
        }
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
            "playlistName": lastPlaylistName ?? "Playlist"
        ]
        
        UserDefaults.standard.set(mem, forKey: key)
    }
    
    
    // MARK: - Gespeicherten Index für Playlist holen
    func getSavedIndex(for playlist: MusicItemCollection<Track>) -> Int? {
        let key = memoryKey(for: playlist)
        
        guard let data = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        return data["index"] as? Int
    }
    
    // MARK: - Memory lesen (roh)
    private func getSavedMemory(forKey key: String) -> [String: Any]? {
        return UserDefaults.standard.dictionary(forKey: key)
    }

    // MARK: - Resume letzte Wiedergabe
    func resumeLastPlayback() {
        // Wenn wir bereits spielen, einfach toggeln
        if currentTrack != nil {
            togglePlayPause()
            return
        }

        // Falls wir kürzlich gespeichert haben, nutze lastMemoryKey
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
        saveMemory()
    }
}
