import SwiftUI
import MusicKit
import AVKit
import MediaPlayer
#if canImport(UIKit)
import UIKit
#endif

struct FullPlayerView: View {
    @EnvironmentObject var player: MusicPlayerManager
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 6)

            // Cover
            if let artwork = player.currentTrack?.artwork,
               let url = artwork.url(width: 600, height: 600) {
                AsyncImage(url: url) { img in
                    img.resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(maxHeight: 380) // larger cover
                .cornerRadius(12)
            } else {
                Color.gray.opacity(0.3)
                    .frame(maxHeight: 380)
                    .cornerRadius(12)
            }

            // Titel / Artist / Album
            VStack(spacing: 8) {
                Text(player.currentTrack?.title ?? "Kein Titel")
                    .font(.largeTitle)
                    .bold()
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(player.currentTrack?.artistName ?? "Unbekannter Künstler")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(player.currentTrack?.albumTitle ?? "Album")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal)

            // Fortschritt + Zeiten
            VStack(spacing: 8) {
                Slider(
                    value: .constant(player.playbackTime),
                    in: 0...max(player.playbackDuration, 1)
                )
                .disabled(true)

                HStack {
                    Text(format(time: player.playbackTime))
                        .font(.caption)
                    Spacer()
                    let remaining = max(player.playbackDuration - player.playbackTime, 0)
                    Text("-" + format(time: remaining))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Shuffle + Previous + Play + Next + Repeat
            HStack(spacing: 40) {
                // SHUFFLE BUTTON
                Button {
                    player.shuffleEnabled.toggle()
                    if UserDefaults.standard.bool(forKey: "pm_haptics_enabled") {
                        #if canImport(UIKit)
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        #endif
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title2)
                        .foregroundColor(player.shuffleEnabled ? .green : .primary)
                }

                // PREVIOUS
                Button {
                    player.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.largeTitle)
                }

                // PLAY / PAUSE
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }

                // NEXT
                Button {
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }

                // REPEAT BUTTON (3-stufig)
                Button {
                    toggleRepeat()
                } label: {
                    Image(systemName: repeatIcon())
                        .font(.title2)
                        .foregroundColor(player.repeatMode == .off ? .primary : .green)
                }
            }
            .padding(.top, 10)

            // Volume + AirPlay
            VStack(spacing: 12) {
                // System volume slider
                SystemVolumeSlider()
                    .frame(height: 32)
                    .padding(.horizontal)

                // AirPlay route picker centered
                HStack {
                    Spacer()
                    AirPlayRoutePicker()
                        .frame(width: 44, height: 44)
                    Spacer()
                }
            }

            Spacer(minLength: 8)
        }
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging downward
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        player.isShowingFullPlayer = false
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
        )
        .padding()
    }

    // MARK: - Repeat Symbol abhängig vom Modus
    private func repeatIcon() -> String {
        switch player.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    // MARK: - Toggle Repeat Mode (off -> all -> one -> off)
    private func toggleRepeat() {
        switch player.repeatMode {
        case .off:
            player.repeatMode = .all
        case .all:
            player.repeatMode = .one
        case .one:
            player.repeatMode = .off
        }
        if UserDefaults.standard.bool(forKey: "pm_haptics_enabled") {
            #if canImport(UIKit)
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            #endif
        }
    }

    // MARK: - Zeitformat mm:ss
    private func format(time: TimeInterval) -> String {
        let totalSeconds = Int(time.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.activeTintColor = UIColor.systemBlue
        view.tintColor = UIColor.label
        // Use a large symbol configuration comparable to .largeTitle icons
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular, scale: .default)
        // Configure the embedded button directly since AVRoutePickerView doesn't expose a style API
        if let button = view.subviews.compactMap({ $0 as? UIButton }).first {
            // Prefer a plain configuration to avoid default filled styling on some OS versions
            if #available(iOS 15.0, tvOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.preferredSymbolConfigurationForImage = symbolConfig
                button.configuration = config
            }
            // Also set preferred symbol configuration for older styles
            button.setPreferredSymbolConfiguration(symbolConfig, forImageIn: .normal)
        }
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
