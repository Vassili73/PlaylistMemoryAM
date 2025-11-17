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
        
        let mem: [String: Any] = [
            "index": index
        ]
        
        UserDefaults.standard.set(mem, forKey: key)
    }
    
    
    // MARK: - Gespeicherten Index für Playlist holen
    func getSavedIndex(for playlist: MusicItemCollection<Track>) -> Int? {
        let key = memoryKey(for: playlist)
        
        guard let data = UserDefaults.standard.dictionary(forKey: key) else { return nil }
        return data["index"] as? Int
    }
    
    
    // MARK: - Shuffle (intern verwaltet)
    func toggleShuffle() {
        shuffleEnabled.toggle()
        
        guard !playlist.isEmpty else { return }
        
        if shuffleEnabled {
            // Shuffle aktiv → Playlist mischen
            let current = currentTrack
            playlist = MusicItemCollection(playlist.shuffled())
            
            if let current = current,
               let newIndex = playlist.firstIndex(of: current) {
                index = newIndex
            } else {
                index = 0
            }
        } else {
            // Shuffle aus: hier könntest du optional wieder Original-Reihenfolge laden,
            // aktuell lassen wir einfach die aktuelle Reihenfolge.
        }
        
        saveMemory()
    }
    
    
    // MARK: - Repeat Modus wechseln
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
        
        saveMemory()
    }
}
