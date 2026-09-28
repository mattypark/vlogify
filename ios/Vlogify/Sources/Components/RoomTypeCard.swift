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
        }
        .buttonStyle(StickerButtonStyle(fill: selected ? fill : .card, radius: Radius.card))
        .stickerRoom()
        .accessibilityIdentifier("newRoom.type.\(type.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: Color {
        switch type {
        case .log: return .action
        case .stack: return .fog
        default: return .fog
        }
    }

    private var glyph: Doodle {
        switch type {
        case .log: return .friends
        case .stack: return .frames
        default: return .page
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
                        .font(.vlogShout)
                        .foregroundStyle(Color.text)
                        .frame(minWidth: 48)
                        .frame(height: 48)
                        .padding(.horizontal, option == 20 ? Space.sm : 0)
                }
                .buttonStyle(StickerButtonStyle(fill: capacity == option ? .fog : .card, radius: Radius.pill))
                .stickerRoom()
                .accessibilityIdentifier("newRoom.size.\(option)")
                .accessibilityAddTraits(capacity == option ? .isSelected : [])
            }
        }
    }
}
