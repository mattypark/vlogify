import SwiftUI
import VlogifyDesign

/// The big full-width button. A sticker with a shout on it.
struct PillButton: View {
    enum Style { case filled, outlined, accent }

    let title: LocalizedStringKey
    var icon: String? = nil
    var style: Style = .filled
    var isLoading = false
    let action: () -> Void

    var body: some View {
        ChunkyButton(title: title, icon: icon, fill: fill, ink: ink, isLoading: isLoading, action: action)
    }

    private var fill: Color {
        switch style {
        case .filled: return .text
        case .outlined: return .card
        case .accent: return .action
        }
    }

    private var ink: Color {
        switch style {
        // White on both dark lids. Slate on the action blue is 4.17:1 -- under AA, and
        // the whole reason `blue` is not a Fill.
        case .filled, .accent: return .card
        case .outlined: return .text
        }
    }
}

/// A small pill that is not pressable on its own: a label inside a sentence.
struct Chip: View {
    let text: String
    var selected = false
    var onPaper = false

    var body: some View {
        Text(verbatim: text)
            .font(.vlogLabel)
            .foregroundStyle(Color.text)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .sticker(fill: selected ? .action : .card, radius: Radius.pill)
            .stickerRoom()
    }
}

/// The round bar buttons. Kept as an alias so older call sites read the same.
struct RoundButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = Metrics.barButton
    var tint: Color = .text
    var fill: Color = .card
    let action: () -> Void

    var body: some View {
        ChunkyRound(systemImage: systemImage, label: label, size: size, fill: fill, ink: tint, action: action)
    }
}
