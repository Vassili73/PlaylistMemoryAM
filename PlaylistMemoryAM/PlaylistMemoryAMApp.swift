//
//  PlaylistMemoryAMApp.swift
//  PlaylistMemoryAM
//
//  Created by Vassilios Maginas on 16.11.25.
//

import SwiftUI
import SwiftData
import Combine
import MusicKit

final class AppRouter: ObservableObject {
    @Published var deepLinkPlaylistID: MusicItemID? = nil
    @Published var deepLinkTrackID: MusicItemID? = nil
}

@main
struct PlaylistMemoryAMApp: App {
    @StateObject private var router = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MusicPlayerManager.shared)
                .environmentObject(router)
                .onOpenURL { url in
                    // Expected formats:
                    // playlistmemory://playlist/<id>
                    // playlistmemory://track/<id>
                    guard url.scheme == "playlistmemory" else { return }
                    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let components = path.split(separator: "/").map(String.init)
                    guard components.count >= 2 else { return }
                    let type = components[0]
                    let idString = components[1]
                    // MusicItemID can be constructed from a string
                    let itemID = MusicItemID(idString)
                    switch type {
                    case "playlist":
                        router.deepLinkPlaylistID = itemID
                    case "track":
                        router.deepLinkTrackID = itemID
                    default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

