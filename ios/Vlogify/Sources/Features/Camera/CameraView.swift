import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// The preview in a rounded frame, the hour, the smiley shutter. Tap = two seconds,
/// one take, posted.
struct CameraView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let camera: CameraSession

    @State private var target: Room?
    @State private var progress: Double = 0
    @State private var hintDismissed = false
    @State private var posting = false
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                if state.permissions.isDenied {
                    deniedView
                } else {
                    CameraPreview(camera: camera)
                }
                overlay
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.frame, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.frame, style: .continuous)
                .stroke(camera.isRecording ? Color.orchid : Color.clear, lineWidth: 3))
            .padding(.horizontal, Space.xs)
            .padding(.top, Space.xs)
        }
        .task {
            await state.permissions.refresh()
            if target == nil { target = state.capturableRooms.first ?? state.rooms.first }
            await camera.start()
        }
        .onDisappear { camera.stop() }
        .confirmationDialog("post to", isPresented: $showPicker, titleVisibility: .visible) {
            ForEach(state.rooms) { room in
                Button(room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled log", bundle: .app))) { target = room }
            }
        }
        .screen("screen.camera")
    }

    private var slot: Slot { state.clock.currentSlot }
    private var alreadyPosted: Bool {
        guard let target else { return false }
        return target.type != .vlog && state.hasPosted(in: target, slot: slot)
    }

    private var overlay: some View {
        VStack {
            HStack {
                roomPicker
                Spacer()
                orientationButton
            }
            .padding(Space.md)
            Spacer()
            // The stamp reads along the long edge of the *recording*. Tap it to flip
            // between horizontal and vertical; the hint and the stitch follow.
            Button {
                Haptics.tap()
                state.capture.toggle()
                hintDismissed = false
            } label: {
                HourStamp(label: slot.label, rotated: state.capture.isLandscape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(state.capture.isLandscape ? "horizontal. tap for vertical" : "vertical. tap for horizontal"))
            .accessibilityIdentifier("camera.stamp")
            Spacer()
            if state.rooms.isEmpty {
                Text("make or join a room first.")
                    .font(.vlogCaption).foregroundStyle(Color.paper)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                    .background(Color.ink.opacity(0.7), in: Capsule())
            } else if alreadyPosted {
                Text("you already posted \(slot.label). next hour!")
                    .font(.vlogCaption).foregroundStyle(Color.paper)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                    .background(Color.ink.opacity(0.7), in: Capsule())
                    .accessibilityIdentifier("camera.posted")
            } else if state.capture.isLandscape, !camera.isLandscape, !hintDismissed {
                Button { hintDismissed = true } label: {
                    Text("rotate to capture")
                        .font(.vlogCaption).foregroundStyle(Color.paper)
                        .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                        .background(Color.ink.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("camera.rotateHint")
            }
            shutter
                .padding(.bottom, Space.lg)
                .padding(.top, Space.sm)
        }
    }

    private var roomPicker: some View {
        Button { if state.rooms.count > 1 { showPicker = true } } label: {
            HStack(spacing: Space.xxs) {
                Text(verbatim: target?.name ?? (target?.isSolo == true ? String(localized: "just me", bundle: .app) : String(localized: "pick a room", bundle: .app)))
                if state.rooms.count > 1 { Image(systemName: "chevron.down") }
            }
            .font(.vlogCaption).foregroundStyle(Color.paper)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("camera.room")
    }

    /// `horizontal` / `vertical`, top-right of the preview.
    private var orientationButton: some View {
        Button {
            Haptics.tap()
            state.capture.toggle()
            hintDismissed = false
        } label: {
            HStack(spacing: Space.xxs) {
                Image(systemName: state.capture.isLandscape ? "rectangle" : "rectangle.portrait")
                Text(state.capture.isLandscape ? "horizontal" : "vertical")
            }
            .font(.vlogCaption).foregroundStyle(Color.paper)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("camera.orientation")
    }

    private var shutter: some View {
        Button { capture() } label: {
            ZStack {
                Circle()
                    .stroke(Color.paper.opacity(0.35), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orchid, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                DoodleSticker(.shutterSmile, scale: 0.82)
                    .scaleEffect(camera.isRecording ? 0.92 : 1)
            }
            .frame(width: Metrics.shutter, height: Metrics.shutter)
        }
        .buttonStyle(.plain)
        .disabled(posting || state.rooms.isEmpty || alreadyPosted || state.permissions.isDenied)
        .opacity(alreadyPosted ? 0.4 : 1)
        .accessibilityLabel(Text(camera.isRecording ? "recording" : "record"))
        .accessibilityIdentifier("camera.shutter")
    }

    private var deniedView: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "camera.fill").font(Font.system(size: 36)).foregroundStyle(Color.textSoft)
            Text("vlogify needs the camera and microphone to record a clip.")
                .font(.vlogBody).foregroundStyle(Color.text).multilineTextAlignment(.center)
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.vlogLabel).foregroundStyle(Color.orchidInk)
            .frame(height: Metrics.hitTarget)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.card)
        .screen("camera.denied")
    }

    private func capture() {
        guard let target, !posting else { return }
        let limit = RoomRules.clipLimit(for: target.type)
        posting = true
        Haptics.shutter()
        withAnimation(Motion.respecting(Motion.ring, reduceMotion: reduceMotion)) { progress = 1 }
        Task {
            defer { posting = false; progress = 0 }
            do {
                let file = try await camera.record(maxSeconds: limit ?? 30)
                try await post(file, to: target)
                Haptics.success()
                state.show(.success(String(localized: "posted \(slot.label).", bundle: .app)))
            } catch ContractError.slotAlreadyPosted {
                state.show(.error(String(localized: "you already posted this hour.", bundle: .app)))
            } catch {
                state.show(.error(String(localized: "couldn't save that clip. try again.", bundle: .app)))
            }
        }
    }

    private func post(_ file: URL, to room: Room) async throws {
        guard let session = state.session else { throw ContractError.notSignedIn }
        let asset = AVURLAsset(url: file)
        let duration = (try? await asset.load(.duration).seconds) ?? 2
        let size = (try? await asset.loadTracks(withMediaType: .video).first?.load(.naturalSize)) ?? CGSize(width: 1080, height: 1920)
        let id = "\(room.id)-\(session.userID)-\(slot.key)-\(Int(Date().timeIntervalSince1970))"
        var clip = Clip(id: id, roomID: room.id, memberID: session.userID, day: slot.day, hour: slot.hour,
                        durationMs: Int(duration * 1000), width: Int(size.width), height: Int(size.height),
                        storageKey: "", createdAt: Date())
        // Local first, then the upload. A dropped connection here costs nothing:
        // the tile is filled from the cache and the upload retries on foreground.
        let local = try state.cache.store(recording: file, as: clip)
        let signed = try await state.backend.media.uploadURL(for: clip)
        clip.storageKey = signed.storageKey
        try await state.backend.media.upload(fileURL: local, to: signed)
        _ = try await state.backend.clips.post(clip)
        await state.loadRooms()
    }
}

import AVFoundation
