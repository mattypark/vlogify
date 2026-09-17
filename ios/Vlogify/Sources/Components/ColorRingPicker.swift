import SwiftUI
import VlogifyDesign

/// Twelve chunky dots. Your pick is your profile colour: the disc by your name, the
/// ring on your tiles, the frame while you record. Friends see it, so it goes through
/// the profile, which already carries it as `avatarSeed`.
struct ColorRingPicker: View {
    @Environment(AppState.self) private var state
    var compact = false

    var body: some View {
        let current = state.profile?.avatarSeed ?? 0
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: compact ? 12 : 6), spacing: Space.xs) {
            ForEach(0..<12, id: \.self) { seed in
                Button {
                    Haptics.tap()
                    Task { await state.setAvatarSeed(seed) }
                } label: {
                    Circle()
                        .fill(Color.avatar(seed: seed))
                        .overlay(Circle().strokeBorder(Color.text, lineWidth: Sticker.line))
                        .overlay {
                            if current % 12 == seed {
                                Image(systemName: "checkmark").font(Font.system(size: compact ? 10 : 14, weight: .black)).foregroundStyle(Color.text)
                            }
                        }
                        .frame(width: compact ? 22 : 36, height: compact ? 22 : 36)
                }
                .buttonStyle(SquashButtonStyle())
                .accessibilityLabel(Text("colour \(seed + 1)"))
                .accessibilityAddTraits(current % 12 == seed ? .isSelected : [])
                .accessibilityIdentifier("ring.\(seed)")
            }
        }
    }
}
