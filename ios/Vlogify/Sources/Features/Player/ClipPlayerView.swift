import AVKit
import SwiftUI
import VlogifyContract
import VlogifyDesign

/// One clip, full screen, looping. Tap anywhere to close.
struct ClipPlayerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let clip: Clip
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
            } else {
                ProgressView().tint(Color.chalk)
            }
            VStack {
                HStack {
                    Spacer()
                    RoundButton(systemImage: "xmark", label: "close") { dismiss() }
                        .padding(Space.md)
                        .accessibilityIdentifier("player.close")
                }
                Spacer()
                HourStamp(label: clip.slot.label, size: 32).padding(.bottom, Space.xl)
            }
        }
        .task {
            guard let url = try? await state.cache.localURL(for: clip, media: state.backend.media) else { return }
            let player = AVPlayer(url: url)
            player.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                Task { @MainActor in
                    await player.seek(to: .zero)
                    player.play()
                }
            }
            self.player = player
        }
        .onDisappear { player?.pause() }
        .screen("screen.clipPlayer")
    }
}
