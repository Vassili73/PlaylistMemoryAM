import SwiftUI
import MusicKit

struct MiniPlayerView: View {
    @EnvironmentObject var playerManager: MusicPlayerManager
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if let track = playerManager.currentTrack {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .opacity(0.95)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if let artwork = track.artwork,
                           let url = artwork.url(width: 100, height: 100) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 44, height: 44)
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(track.artistName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Button(action: { playerManager.togglePlayPause() }) {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }

                        Button(action: { playerManager.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { playerManager.isShowingFullPlayer = true }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                // Thin progress bar at top
                GeometryReader { geo in
                    let width = max(0, min(geo.size.width - 24, geo.size.width))
                    let progress = playerManager.playbackDuration > 0 ? CGFloat(playerManager.playbackTime / playerManager.playbackDuration) : 0
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: width * progress, height: 2)
                        .padding(.top, 4)
                        .padding(.leading, 12)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 64)
            .shadow(radius: 8)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = min(0, value.translation.height)
                    }
                    .onEnded { value in
                        if value.translation.height < -60 {
                            playerManager.isShowingFullPlayer = true
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
            )
        } else {
            EmptyView()
        }
    }
}
