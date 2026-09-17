import SwiftUI
import VlogifyDesign

/// The app's pressable vocabulary, all stickers. One place, so every button in the app
/// presses the same way.

/// A full-width sticker button with a shout on it.
struct ChunkyButton: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    var fill: Color = .action
    /// White by default, because the default fill is the action blue and slate on it is
    /// 4.17:1. A light lid has to say so.
    var ink: Color = .card
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if isLoading {
                    ProgressView().tint(ink)
                } else if let icon {
                    Image(systemName: icon).font(Font.system(size: 18, weight: .bold))
                }
                Text(title).font(.vlogShout)
            }
            .foregroundStyle(ink)
            // folk's `text-shadow: 0 1px #00285A59`: on a coloured lid it is what keeps a
            // white shout crisp. On a pale lid with slate text it would just look dirty.
            .shadow(color: ink == .card ? Color.ink.opacity(0.35) : .clear, radius: 0, y: 1)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(StickerButtonStyle(fill: fill, radius: Radius.pill))
        .disabled(isLoading)
        .stickerRoom()
    }
}

/// A small sticker: `create log`, a size number, a language row.
struct ChunkyChip: View {
    let text: String
    var fill: Color = .card
    var ink: Color = .text
    var selected = false
    var height: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: text)
                .font(.vlogLabel)
                .foregroundStyle(ink)
                .padding(.horizontal, Space.md)
                .frame(height: height)
        }
        .buttonStyle(StickerButtonStyle(fill: selected ? fill : .card, radius: Radius.pill))
        .stickerRoom()
    }
}

/// The round bar buttons: bell, plus, flip, flash, close.
struct ChunkyRound: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = Metrics.barButton
    var fill: Color = .card
    var ink: Color = .text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Font.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: size, height: size)
        }
        .buttonStyle(StickerCircleStyle(fill: fill))
        .stickerRoom()
        .accessibilityLabel(Text(label))
    }
}

/// A card that is not pressable but still a sticker: room blocks, the invite code.
struct StickerCard<Content: View>: View {
    var fill: Color = .card
    var radius: CGFloat = Radius.card
    @ViewBuilder let content: Content

    var body: some View {
        content
            .sticker(fill: fill, radius: radius)
            .stickerRoom()
    }
}
