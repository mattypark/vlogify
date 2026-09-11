import SwiftUI
import VlogifyDesign
import VlogifyEngine

/// One of the three tall cards on the new-room sheet.
struct RoomTypeCard: View {
    let type: RoomType
    let selected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.sm) {
                DoodleSticker(glyph, scale: 0.9)
                    .padding(.top, Space.sm)
                Text(title)
                    .font(.vlogLabel)
                    .foregroundStyle(Color.text)
                    .padding(.bottom, Space.sm)
            }
            .frame(maxWidth: .infinity)
            .background(selected ? Color.orchid.opacity(0.35) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(selected ? Color.orchid : Color.clear, lineWidth: 2))
            .scaleEffect(selected ? 1.0 : 0.96)
            .animation(Motion.respecting(Motion.tap, reduceMotion: reduceMotion), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("newRoom.type.\(type.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var glyph: Doodle {
        switch type {
        case .log: return .glyphLog
        case .stack: return .glyphStack
        default: return .glyphVlog
        }
    }

    private var title: LocalizedStringKey {
        switch type {
        case .log: return "log"
        case .stack: return "stack"
        case .vlog: return "vlog"
        case .zip: return "zip"
        }
    }
}

/// The capacity pills: 2 3 4 5 6-20.
struct SizePicker: View {
    let type: RoomType
    @Binding var capacity: Int

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(RoomRules.capacityOptions(for: type), id: \.self) { option in
                Button {
                    Haptics.tap()
                    capacity = option
                } label: {
                    Text(verbatim: RoomRules.capacityLabel(option, for: type))
                        .font(Font.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.text)
                        .frame(minWidth: 52)
                        .frame(height: 52)
                        .padding(.horizontal, option == 20 ? Space.sm : 0)
                        .background(capacity == option ? Color.orchid.opacity(0.35) : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(capacity == option ? Color.orchid : Color.hairline, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("newRoom.size.\(option)")
                .accessibilityAddTraits(capacity == option ? .isSelected : [])
            }
        }
    }
}
