import SwiftUI
import VlogifyDesign

/// The bar: "today" on the left, the record button in the middle, one tool on the right
/// (`+` on the page, flip on the camera). On the page, "today" opens every past day on a
/// drawn calendar; on the camera it becomes "back". The record button is the biggest
/// thing on the bar because filming is the point.
struct BottomBar<Trailing: View>: View {
    @Binding var tab: AppState.Tab
    let onToday: () -> Void
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Button {
                Haptics.tap()
                if tab == .camera {
                    withAnimation(Motion.shift) { tab = .logs }
                } else {
                    onToday()
                }
            } label: {
                VStack(spacing: 2) {
                    if tab == .camera {
                        DoodleSticker(.arrowLeft, scale: 0.9, lineWidth: 2)
                            .frame(height: 34)
                        Text("back")
                            .font(.vlogHandSmall)
                            .foregroundStyle(Color.text)
                    } else {
                        DoodleSticker(.page, scale: 0.24, lineWidth: 1.6)
                        Text("today")
                            .font(.vlogHandSmall)
                            .foregroundStyle(Color.text)
                    }
                }
                .frame(width: Metrics.barButton + 8, height: Metrics.barButton)
            }
            .buttonStyle(SquashButtonStyle())
            .accessibilityLabel(Text(tab == .camera ? "back" : "today"))
            .accessibilityHint(Text(tab == .camera ? "back to your page" : "shows your past days"))
            .accessibilityIdentifier(tab == .camera ? "bar.back" : "bar.today")
            .tourAnchor(.days)

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
            .tourAnchor(.record)

            Spacer()

            trailing
                .frame(width: Metrics.barButton + 8)
                .tourAnchor(.rooms)
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

/// The `+` on the bar. It looks exactly as it always has; what it opens is a drawn card
/// (`PlusCard`) instead of a system menu.
struct PlusButton: View {
    let open: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            open()
        } label: {
            DoodleSticker(.plus, scale: 1.1, lineWidth: 2.2)
                .frame(width: Metrics.barButton, height: Metrics.barButton)
                .sticker(fill: .card, corner: .circle)
        }
        .buttonStyle(SquashButtonStyle())
        .stickerRoom()
        .accessibilityLabel(Text("new"))
        .accessibilityIdentifier("bar.plus")
    }
}

/// What `+` opens: a small card drawn above the button, its outline tracing in, then each
/// choice written in with its glyph. Tap outside, or `+` again, to put it away.
struct PlusCard: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.ground.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                choice(.plus, String(localized: "start a room", bundle: .app), delay: 0.45, id: "plus.create", action: onCreate)
                DrawnRule(seed: 5, delay: 0.6, animated: true)
                    .padding(.horizontal, Space.xs)
                choice(.hash, String(localized: "join with a code", bundle: .app), delay: 0.7, id: "plus.join", action: onJoin)
            }
            .padding(Space.xs)
            .frame(width: 290)
            .sticker(fill: .card, corner: .radius(Radius.card), drawIn: 0)
            .padding(.trailing, Space.gutter)
            // Sits just above the `+` on the bar below.
            .padding(.bottom, Space.sm)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
    }

    private func choice(_ glyph: Doodle, _ text: String, delay: Double, id: String, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: Space.sm) {
                DoodleSticker(glyph, scale: 1, animated: true, lineWidth: 2, delay: delay)
                    .frame(width: 28, height: 28)
                HandwrittenText(text: text, font: .vlogHand, delay: delay + 0.1, perLine: 0.35)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.sm)
            .frame(minHeight: Metrics.hitTarget + 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
