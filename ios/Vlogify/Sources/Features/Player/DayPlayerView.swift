import AVKit
import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// The stitched day. Composes on open, plays, and exports to Photos on request.
struct DayPlayerView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let room: Room
    let log: DayLog

    enum Phase: Equatable { case composing, ready, exporting, saved, failed(String) }
    @State private var phase: Phase = .composing
    @State private var player: AVPlayer?
    @State private var output: URL?

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            VStack(spacing: Space.md) {
                HStack {
                    RoundButton(systemImage: "xmark", label: "close") { dismiss() }
                        .accessibilityIdentifier("dayPlayer.close")
                    Spacer()
                    Text(verbatim: state.clock.formatted(log.day)).font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                    Spacer()
                    Color.clear.frame(width: Metrics.barButton, height: Metrics.barButton)
                }
                .padding(.horizontal, Space.gutter)
                Group {
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.frame, style: .continuous))
                            .onAppear { player.play() }
                    } else {
                        VStack(spacing: Space.sm) {
                            ProgressView().tint(Color.chalk)
                            Text(phase == .composing ? "stitching \(log.postedSlots.count) hours…" : "")
                                .font(.vlogCaption).foregroundStyle(Color.chalkSoft)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.cardRaised, in: RoundedRectangle(cornerRadius: Radius.frame, style: .continuous))
                    }
                }
                .padding(.horizontal, Space.xs)
                footer
            }
        }
        .task { await compose() }
        .onDisappear { player?.pause() }
        .screen("screen.dayPlayer")
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .composing:
            Color.clear.frame(height: 56)
        case .ready, .exporting:
            HStack(spacing: Space.sm) {
                PillButton(title: "save to photos", icon: "square.and.arrow.down", style: .accent, isLoading: phase == .exporting) {
                    Task { await save() }
                }
                .accessibilityIdentifier("dayPlayer.save")
                if let output {
                    ShareLink(item: output) {
                        Image(systemName: "square.and.arrow.up").font(Font.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.chalk).frame(width: 56, height: 56)
                            .background(Color.cardRaised, in: Circle())
                    }
                    .accessibilityIdentifier("dayPlayer.share")
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.md)
        case .saved:
            Text("saved to photos. post it anywhere.")
                .font(.vlogLabel).foregroundStyle(Color.goodInk)
                .frame(height: 56)
                .accessibilityIdentifier("dayPlayer.saved")
        case .failed(let message):
            Text(verbatim: message).font(.vlogCaption).foregroundStyle(Color.warnInk).frame(height: 56)
                .accessibilityIdentifier("dayPlayer.failed")
        }
    }

    private func compose() async {
        var files: [ClipID: URL] = [:]
        for clip in log.clips {
            if let url = try? await state.cache.localURL(for: clip, media: state.backend.media) { files[clip.id] = url }
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("vlogify-\(room.id)-\(log.day).mp4")
        do {
            let input = DayCompositor.Input(log: log, files: files, clipDuration: RoomRules.clipLimit(for: room.type) ?? 2,
                                            orientation: state.capture.orientation, stampFont: state.capture.stampFont)
            let url = try await DayCompositor().export(input, to: destination)
            output = url
            let player = AVPlayer(url: url)
            self.player = player
            phase = .ready
        } catch {
            phase = .failed(String(localized: "couldn't stitch the day. try again.", bundle: .app))
        }
    }

    private func save() async {
        guard let output else { return }
        phase = .exporting
        do {
            try await PhotosExporter.save(video: output)
            Haptics.success()
            phase = .saved
        } catch PhotosExporter.Failure.denied {
            phase = .failed(String(localized: "allow photos access in settings to save.", bundle: .app))
        } catch {
            phase = .failed(String(localized: "couldn't save to photos.", bundle: .app))
        }
    }
}
