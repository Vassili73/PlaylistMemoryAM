import Foundation
import MusicKit

struct PlaylistMemoryEntry: Codable {
    let playlistID: MusicItemID
    let trackID: MusicItemID
    let trackIndex: Int
    let timestamp: TimeInterval
}

class PlaylistMemory {
    
    static let shared = PlaylistMemory()
    private let key = "playlist_memory_storage"
    
    private init() {}
    
    // Lade alle gespeicherten Daten
    private func load() -> [PlaylistMemoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PlaylistMemoryEntry].self, from: data)) ?? []
    }
    
    // Speichern
    private func save(_ entries: [PlaylistMemoryEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - SPEICHERN DES ZUSTANDS
    func store(playlist: Playlist,
               track: Track,
               index: Int,
               timestamp: TimeInterval)
    {
        var entries = load()
        
        // Falls dieser Playlist-Eintrag schon existiert → überschreiben
        entries.removeAll { $0.playlistID == playlist.id }
        
        entries.append(
            PlaylistMemoryEntry(
                playlistID: playlist.id,
                trackID: track.id,
                trackIndex: index,
                timestamp: timestamp
            )
        )
        
        save(entries)
    }
    
    // MARK: - ABRUFEN DES LETZTEN ZUSTANDS
    func getLastState(for playlist: Playlist) -> PlaylistMemoryEntry? {
        return load().first { $0.playlistID == playlist.id }
    }
}
