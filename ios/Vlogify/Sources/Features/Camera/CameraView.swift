import SwiftUI
import VlogifyContract
import VlogifyDesign
import VlogifyEngine

/// The preview inside a drawn frame, the hour in the pen hand, a drawn shutter. In a
/// friends' room, tap = two seconds, one take, posted -- and a red pen line draws itself
/// once around the shutter, taking exactly the two seconds. In your own vlog a clip is
/// as long as you want: tap to start, tap to stop (B: hold to film), with a running
/// clock so it is never a guess when it ends.
struct CameraView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let camera: CameraSession

    @State private var target: Room?
    @State private var progress: Double = 0
    @State private var hintDismissed = false
    @State private var posting = false
    @State private var posted = 0

    /// The longest an open-ended clip runs before it stops by itself. The ring fills
    /// towards it, so the limit is visible rather than a surprise.
    private static let openEndedCap: Double = 60
    /// A tap-length hold still makes a watchable clip.
    private static let shortestClip: Double = 0.8

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
            .overlay(PenShape(.radius(Radius.frame), wobble: 1.6)
                .stroke(camera.isRecording ? Color.recording : Color.text, style: Ink.style(camera.isRecording ? 4 : Pen.line)))
            .padding(.horizontal, Space.xs)
            .padding(.top, Space.xs)
        }
        .task {
            await state.permissions.refresh()
            await camera.start()
            #if DEBUG
            // Screenshots of the recording state: the shutter can't be tapped from a script.
            if LaunchArguments.screen == "cameraRecording" {
                try? await Task.sleep(for: .seconds(1))
                capture()
            }
            #endif
        }
        .onDisappear { camera.stop() }
        .screen("screen.camera")
    }

    private var slot: Slot { state.clock.currentSlot }

    /// The room a clip goes to: the one picked, while it still exists, else the first that
    /// can take a clip now. Derived rather than stored once on appear, so rooms that load
    /// (or are made) after the camera opens are never missed.
    private var room: Room? {
        if let target, let picked = state.rooms.first(where: { $0.id == target.id }) { return picked }
        return state.capturableRooms.first ?? state.rooms.first
    }

    private var alreadyPosted: Bool {
        guard let room else { return false }
        return room.type != .vlog && state.hasPosted(in: room, slot: slot)
    }

    /// Whether the hour's tops face 3 o'clock, which reads upright once the phone is turned
    /// top-to-the-left -- so the hint's arrow turns that way. Otherwise it turns clockwise.
    private var stampFacesRight: Bool {
        let turn = state.capture.stampTurn.truncatingRemainder(dividingBy: 360)
        return turn == 90 || turn == -270
    }

    /// Your own vlog: no fixed length, so the person decides when it ends.
    private var isOpenEnded: Bool {
        guard let room else { return false }
        return RoomRules.clipLimit(for: room.type) == nil
    }

    private var holdToFilm: Bool { isOpenEnded && DesignVariant.record == .b }

    private func name(of room: Room) -> String {
        room.name ?? (room.isSolo ? String(localized: "just me", bundle: .app) : String(localized: "untitled room", bundle: .app))
    }

    private var overlay: some View {
        ZStack {
            controls
            // Dead centre of the preview, not of the space between the controls.
            stamp
        }
    }

    /// The hour, turned however you last left it. Each tap turns it a quarter clockwise and
    /// the angle is kept, separately for sideways and upright. Horizontal/vertical is the
    /// button top-right.
    private var stamp: some View {
        Button {
            Haptics.tap()
            state.capture.turnStamp()
        } label: {
            HourStamp(label: slot.label, turn: state.capture.stampTurn, font: state.capture.stampFont)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: slot.label))
        .accessibilityHint(Text("turns the time a quarter turn"))
        .accessibilityIdentifier("camera.stamp")
    }

    private var controls: some View {
        VStack {
            HStack(spacing: Space.xs) {
                roomPicker
                Spacer()
                torchButton
                fontButton
                orientationButton
            }
            .padding(Space.md)
            Spacer()
            if state.rooms.isEmpty {
                Text("make or join a room first.")
                    .font(.vlogCaption).foregroundStyle(Color.chalk)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                    .background(Color.ink.opacity(0.7), in: Capsule())
            } else if alreadyPosted {
                Text("you already posted \(slot.label). next hour!")
                    .font(.vlogCaption).foregroundStyle(Color.chalk)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xs)
                    .background(Color.ink.opacity(0.7), in: Capsule())
                    .accessibilityIdentifier("camera.posted")
            } else if state.capture.isLandscape, !camera.isLandscape, !hintDismissed {
                Button { hintDismissed = true } label: {
                    HStack(spacing: Space.xs) {
                        Text("turn me sideways")
                            .font(.vlogAnnotation)
                        DoodleSticker(.arrowTurn, scale: 0.6, animated: true, lineWidth: 2, color: .chalk)
                            .scaleEffect(x: stampFacesRight ? -1 : 1)
                    }
                    .foregroundStyle(Color.chalk)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xxs)
                    .background(Color.ink.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("camera.rotateHint")
            }
            if camera.isRecording {
                recordingClock
            } else if isOpenEnded, !alreadyPosted, !state.rooms.isEmpty {
                Text(holdToFilm ? "hold to film" : "tap to start · tap to stop")
                    .font(.vlogCaption).foregroundStyle(Color.chalk)
                    .padding(.horizontal, Space.md).padding(.vertical, Space.xxs)
                    .background(Color.ink.opacity(0.6), in: Capsule())
                    .accessibilityIdentifier("camera.howTo")
            }
            shutter
                .padding(.bottom, Space.lg)
                .padding(.top, Space.sm)
        }
    }

    /// Where the clip goes. A menu anchored on the pill, so a tap always opens it, even
    /// with one room.
    private var roomPicker: some View {
        Menu {
            Section("post to") {
                ForEach(state.rooms) { option in
                    Button { target = option } label: {
                        if option.id == room?.id {
                            Label(name(of: option), systemImage: "checkmark")
                        } else {
                            Text(verbatim: name(of: option))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Space.xxs) {
                Text(verbatim: room.map(name(of:)) ?? String(localized: "pick a room", bundle: .app))
                Image(systemName: "chevron.down")
            }
            .lineLimit(1)
            .frame(maxWidth: 190, alignment: .leading)
            .font(.vlogCaption).foregroundStyle(Color.chalk)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .disabled(state.rooms.isEmpty)
        .accessibilityIdentifier("camera.room")
    }

    private var torchButton: some View {
        Button {
            Haptics.tap()
            camera.toggleTorch()
        } label: {
            Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash")
                .font(.vlogCaption)
                .foregroundStyle(Color.chalk)
                .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(camera.isTorchOn ? "flash on" : "flash off"))
        .accessibilityIdentifier("camera.flash")
    }

    /// Cycles the stamp's face. The label is the face itself, so it previews.
    private var fontButton: some View {
        Button {
            Haptics.tap()
            state.capture.shuffleFont()
        } label: {
            Text(verbatim: "Aa")
                .font(state.capture.stampFont.font(size: 15))
                .foregroundStyle(Color.chalk)
                .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
                .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("change the time's font"))
        .accessibilityIdentifier("camera.font")
    }

    /// `horizontal` / `vertical`, top-right of the preview.
    private var orientationButton: some View {
        Button {
            Haptics.tap()
            state.capture.toggle()
            hintDismissed = false
        } label: {
            // Icon only: the room name next to it needs the width more.
            Image(systemName: state.capture.isLandscape ? "rectangle" : "rectangle.portrait")
            .font(.vlogCaption).foregroundStyle(Color.chalk)
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(Color.ink.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(state.capture.isLandscape ? "horizontal" : "vertical"))
        .accessibilityIdentifier("camera.orientation")
    }

    /// A red dot and the seconds so far, ticking from the moment frames land, plus how
    /// it ends: on its own (two seconds), at a tap, or when you let go.
    private var recordingClock: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = camera.recordingStartedAt.map { context.date.timeIntervalSince($0) } ?? 0
            HStack(spacing: Space.xs) {
                Circle().fill(Color.recording).frame(width: 10, height: 10)
                Text(verbatim: Self.clockText(elapsed))
                    .font(Font.system(size: 17, weight: .bold).monospacedDigit())
                if isOpenEnded {
                    Text(holdToFilm ? "let go to stop" : "tap to stop")
                        .font(.vlogCaption)
                }
            }
            .foregroundStyle(Color.chalk)
            .padding(.horizontal, Space.md).padding(.vertical, Space.xxs)
            .background(Color.ink.opacity(0.75), in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("camera.clock")
    }

    private static func clockText(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private var shutterDisabled: Bool {
        // An open-ended clip has to stay tappable (and holdable) while it records; a
        // double start is already refused by `capture()`.
        (posting && !isOpenEnded) || state.rooms.isEmpty || alreadyPosted || state.permissions.isDenied
    }

    private var shutterFace: some View {
        ZStack {
            // The clip's length, drawn: a pen loop that starts where a hand would and
            // closes as the clip ends -- two seconds in a room, the cap in your vlog.
            PenShape(.circle, seed: 3, wobble: 2)
                .trim(from: 0, to: progress)
                .stroke(Color.recording, style: Ink.style(5))
                .padding(-9)
            // Recording an open-ended clip, the dot becomes a stop square.
            RoundedRectangle(cornerRadius: isOpenEnded && camera.isRecording ? 6 : 15, style: .continuous)
                .fill(Color.recording)
                .frame(width: isOpenEnded && camera.isRecording ? 26 : 30, height: isOpenEnded && camera.isRecording ? 26 : 30)
                .animation(Motion.respecting(Motion.tap, reduceMotion: reduceMotion), value: camera.isRecording)
        }
        .frame(width: Metrics.shutter, height: Metrics.shutter)
    }

    @ViewBuilder
    private var shutter: some View {
        Group {
            if holdToFilm {
                // Down starts it, up ends it. Not a Button: a button only fires on release.
                shutterFace
                    .sticker(fill: .card, corner: .circle, pressed: camera.isRecording)
                    .contentShape(Circle())
                    .onLongPressGesture(minimumDuration: 600, maximumDistance: 80, perform: {}) { pressing in
                        guard !shutterDisabled else { return }
                        if pressing { capture() } else { finish() }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { camera.isRecording ? finish() : capture() }
            } else {
                Button {
                    if isOpenEnded, camera.isRecording { finish() } else { capture() }
                } label: { shutterFace }
                .buttonStyle(StickerCircleStyle(fill: .card))
            }
        }
        .rewardBeat(on: posted)
        .disabled(shutterDisabled)
        .opacity(alreadyPosted ? 0.4 : 1)
        .accessibilityLabel(Text(camera.isRecording ? (isOpenEnded ? "stop recording" : "recording") : "record"))
        .accessibilityIdentifier("camera.shutter")
    }

    private var deniedView: some View {
        VStack(spacing: Space.md) {
            DoodleSticker(.camcorder, scale: 0.7)
            Text("vlogify needs the camera and microphone to record a clip.")
                .font(.vlogBody).foregroundStyle(Color.text).multilineTextAlignment(.center)
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.vlogLabel).foregroundStyle(Color.actionInk)
            .frame(height: Metrics.hitTarget)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.card)
        .screen("camera.denied")
    }

    private func capture() {
        guard let target = room, !posting else { return }
        let limit = RoomRules.clipLimit(for: target.type)
        let length = limit ?? Self.openEndedCap
        posting = true
        Haptics.shutter()
        withAnimation(Motion.respecting(limit == nil ? .linear(duration: length) : Motion.ring, reduceMotion: reduceMotion)) {
            progress = 1
        }
        Task {
            defer {
                posting = false
                withAnimation(Motion.respecting(Motion.dismiss, reduceMotion: reduceMotion)) { progress = 0 }
            }
            do {
                let file = try await camera.record(maxSeconds: length)
                let sent = try await post(file, to: target)
                Haptics.success()
                posted += 1
                if sent {
                    state.show(.success(String(localized: "posted \(slot.label).", bundle: .app)))
                } else {
                    state.show(.info(String(localized: "saved on your phone. it'll post when you're back online.", bundle: .app)))
                }
            } catch ContractError.slotAlreadyPosted {
                state.show(.error(String(localized: "you already posted this hour.", bundle: .app)))
            } catch {
                state.show(.error(String(localized: "couldn't save that clip. try again.", bundle: .app)))
            }
        }
    }

    /// Ends an open-ended clip. A stop in the first instant waits out the shortest clip,
    /// so a quick tap (or a too-short hold) still leaves something to watch.
    private func finish() {
        guard posting else { return }
        Haptics.tap()
        Task {
            // A release can beat the recorder starting up; wait for it rather than lose
            // the stop and run to the cap.
            for _ in 0..<40 where camera.recordingStartedAt == nil { try? await Task.sleep(for: .milliseconds(50)) }
            let elapsed = camera.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let wait = max(0, Self.shortestClip - elapsed)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            camera.stopRecording()
        }
    }

    /// Local first, then the upload. Returns false when the clip is safe on the phone
    /// but still queued: a dropped connection costs nothing, the queue retries on the
    /// next foreground. A refusal the backend means (a rule, not the network) throws.
    private func post(_ file: URL, to room: Room) async throws -> Bool {
        guard let session = state.session else { throw ContractError.notSignedIn }
        let asset = AVURLAsset(url: file)
        let duration = (try? await asset.load(.duration).seconds) ?? 2
        let size = (try? await asset.loadTracks(withMediaType: .video).first?.load(.naturalSize)) ?? CGSize(width: 1080, height: 1920)
        // A plain UUID: ids travel in URL paths on the real backend.
        let clip = Clip(id: UUID().uuidString.lowercased(), roomID: room.id, memberID: session.userID,
                        day: slot.day, hour: slot.hour, durationMs: Int(duration * 1000),
                        width: Int(size.width), height: Int(size.height), storageKey: "", createdAt: Date())
        _ = try state.cache.store(recording: file, as: clip)
        state.uploads.add(clip)
        do {
            _ = try await state.uploads.send(clip, backend: state.backend, cache: state.cache)
        } catch let error as ContractError where UploadQueue.isPermanent(error) {
            state.uploads.remove(clip.id)
            throw error
        } catch {
            await state.loadRooms()
            return false
        }
        await state.loadRooms()
        return true
    }
}

import AVFoundation
