import SwiftUI
import MusicKit

struct ContentView: View {
    
    @StateObject private var musicAuth = MusicAuthManager()
    @StateObject private var player = MusicPlayerManager.shared
    
    @State private var playlists: MusicItemCollection<Playlist> = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            NavigationView {
                VStack(spacing: 20) {
                    
                    Button("Apple Music verbinden") {
                        Task { await musicAuth.requestAuthorization() }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button("Playlists laden") {
                        Task { await loadPlaylists() }
                    }
                    .disabled(!musicAuth.isAuthorized)
                    
                    List(playlists, id: \.id) { playlist in
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
                }
            }
            
            // 🔥 Mini Player — immer ganz unten sichtbar
            MiniPlayerView()
                .environmentObject(player)
                .frame(height: player.currentTrack == nil ? 0 : 70)
                .animation(.easeInOut, value: player.currentTrack)
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
        } catch {
            print("❌ Fehler beim Laden:", error)
        }
    }
}

#Preview {
    ContentView()
}
