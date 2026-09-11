import SwiftUI
import VlogifyDesign

/// The big full-width button on the welcome page and in sheets.
struct PillButton: View {
    enum Style { case filled, outlined, accent }

    let title: LocalizedStringKey
    var icon: String? = nil
    var style: Style = .filled
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else if let icon {
                    Image(systemName: icon).font(Font.system(size: 18, weight: .semibold))
                }
                Text(title).font(.vlogLabel)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(style == .outlined ? Color.line : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var foreground: Color {
        switch style {
        case .filled: return .paper
        case .outlined: return .chalk
        case .accent: return .ink
        }
    }

    private var background: Color {
        switch style {
        case .filled: return .soot
        case .outlined: return .surface
        case .accent: return .orchid
        }
    }
}

/// A small pill: `create log`, a capacity number, the camera/logs segment.
struct Chip: View {
    let text: String
    var selected = false
    var onPaper = false

    var body: some View {
        Text(verbatim: text)
            .font(.vlogLabel)
            .foregroundStyle(selected ? Color.chalk : (onPaper ? Color.soot : Color.chalk))
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(selected ? Color.orchid.opacity(0.35) : (onPaper ? Color.soot.opacity(0.08) : Color.surfaceRaised), in: Capsule())
    }
}

/// The round bar buttons: bell, plus, flip, timer.
struct RoundButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var size: CGFloat = Metrics.barButton
    var tint: Color = .chalk
    var fill: Color = .surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Font.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
