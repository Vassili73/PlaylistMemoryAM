# 🎵 PlaylistMemory AM  
**Ein Apple-Music-Player mit persönlichem Hör-Gedächtnis**

PlaylistMemory AM ist eine iOS-App, die dir ermöglicht, Apple-Music-Playlists abzuspielen – und sich dabei zu merken, **wo du in jeder Playlist zuletzt warst**.  
Selbst wenn du Playlists wechselst oder die App schließt, spielt die App immer **genau dort weiter**, wo du aufgehört hast.

---

## ✨ Features

### 🔊 Wiedergabe
- Play, Pause, Nächster/Hervoriger Track  
- Mini-Player (immer sichtbar)  
- Vollbild-Player mit Cover, Infos, Fortschritt usw.

### 🧠 Playlist-Gedächtnis
- Pro Playlist wird gespeichert:
  - welcher Song zuletzt lief  
  - an welcher Stelle du aufgehört hast  
- Beim Wiederbetreten der Playlist wird automatisch weitergespielt

### 🔀 Shuffle & 🔁 Repeat
- Eigene interne Shuffle-Logik  
- Wiederholen: Off / All / One  
- Funktioniert unabhängig von Apple Music Einschränkungen

### 🎨 UI/UX
- Moderner Mini-Player  
- Fullscreen-Player  
- Playlist-Ansicht mit Cover und Header  
- Sanfte Animationen & iOS-Look

### 🛠 Technik
- SwiftUI  
- MusicKit  
- UserDefaults für persistenten Playlist-State  
- MVVM-ähnliche Struktur mit `MusicPlayerManager`

---

## 📸 Screenshots  
*(Platzhalter – du kannst später echte hinzufügen)*

| Mini Player | Full Player | Playlist View |
|-------------|-------------|----------------|
| ![Mini](docs/screenshot_mini.png) | ![Full](docs/screenshot_full.png) | ![Playlist](docs/screenshot_playlist.png) |

---

## 🚀 Installation / Build
1. App klonen:
   ```bash
   git clone https://github.com/Vassili73/PlaylistMemoryAM.git


PlaylistMemoryAM/
│
├── MusicPlayerManager.swift     // zentrale Wiedergabelogik
├── ContentView.swift            // Hauptansicht + MiniPlayer
├── TracksView.swift             // Playlist-Detail & Songliste
├── FullPlayerView.swift         // Vollbild-Musikplayer
├── MusicAuthManager.swift       // Apple-Music-Berechtigungen
└── PlaylistMemoryAMApp.swift    // App Entry Point


Version History

v1.0.0 – First Stable Version 
	•	Mini-Player
	•	Full-Player
	•	Playlist-Ansicht
	•	Playlist Memory System
	•	Shuffle & Repeat
	•	Fortschrittsanzeige (Timer-Simuliert)
