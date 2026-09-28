import SwiftUI
import VlogifyDesign

/// The bar: today's page on the left, the record button in the middle, one tool on the
/// right (`+` on the page, flip on the camera). The record button is the biggest thing
/// on the bar because filming is the point.
struct BottomBar<Trailing: View>: View {
    @Binding var tab: AppState.Tab
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Button {
                Haptics.tap()
                withAnimation(Motion.shift) { tab = .logs }
            } label: {
                VStack(spacing: 2) {
                    DoodleSticker(.page, scale: 0.24, lineWidth: 1.6)
                    Text("today")
                        .font(.vlogHandSmall)
                        .foregroundStyle(Color.text)
                }
                .frame(width: Metrics.barButton + 8, height: Metrics.barButton)
                .opacity(tab == .logs ? 1 : 0.5)
            }
            .buttonStyle(SquashButtonStyle())
            .accessibilityLabel(Text("today"))
            .accessibilityAddTraits(tab == .logs ? .isSelected : [])
            .accessibilityIdentifier("bar.today")

            Spacer()

            Button {
                Haptics.tap()
                withAnimation(Motion.shift) { tab = .camera }
            } label: {
                ZStack {
                    PenShape(.circle, wobble: 1.6).stroke(Color.text, style: Ink.style(2.4))
                    Circle()
                        .fill(Color.recording)
                        .padding(tab == .camera ? 12 : 17)
                }
                .frame(width: 70, height: 70)
            }
            .buttonStyle(SquashButtonStyle())
            .accessibilityLabel(Text("camera"))
            .accessibilityAddTraits(tab == .camera ? .isSelected : [])
            .accessibilityIdentifier("bar.camera")

            Spacer()

            trailing
                .frame(width: Metrics.barButton + 8)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.xxs)
        .background(Color.ground)
    }
}

/// A drawn round button with a drawn glyph: the bell, flip, back.
struct DoodleRound: View {
    let doodle: Doodle
    let label: LocalizedStringKey
    var size: CGFloat = Metrics.hitTarget + 4
    var fill: Color = .card
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DoodleSticker(doodle, scale: size / (doodle.size.width * 2.1), lineWidth: 1.6)
                .frame(width: size, height: size)
        }
        .buttonStyle(StickerCircleStyle(fill: fill))
        .stickerRoom()
        .accessibilityLabel(Text(label))
    }
}

/// The `+` menu. Create, join, a note -- and a zip, only when it is built.
struct PlusMenu: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    var onNote: () -> Void = {}

    var body: some View {
        Menu {
            Button(action: onCreate) { Label("start a room", systemImage: "plus.square") }
            Button(action: onJoin) { Label("join with a code", systemImage: "number") }
            Button(action: onNote) { Label("add a note", systemImage: "pencil.line") }
            if FeatureFlags.zipPhotos {
                Divider()
                Button {} label: { Label("start a zip", systemImage: "bolt") }
            }
        } label: {
            DoodleSticker(.plus, scale: 1.1, lineWidth: 2.2)
                .frame(width: Metrics.barButton, height: Metrics.barButton)
                .sticker(fill: .card, corner: .circle)
        }
        .stickerRoom()
        .accessibilityLabel(Text("new"))
        .accessibilityIdentifier("bar.plus")
    }
}
