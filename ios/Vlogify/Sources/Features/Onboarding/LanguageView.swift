import SwiftUI
import VlogifyDesign

/// The first screen, and the one behind Profile → language. Six rows in their own
/// scripts; tap one, it applies immediately.
struct LanguageView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// True when opened from Profile: shows a close button instead of `continue`.
    var isChanging = false
    @State private var picked: AppLanguage = AppLanguage.current ?? .suggested

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Wordmark()
                Spacer()
                if isChanging {
                    RoundButton(systemImage: "xmark", label: "close", size: Metrics.hitTarget + 4) { dismiss() }
                        .accessibilityIdentifier("language.close")
                }
            }
            Text(verbatim: "choose your language")
                .font(.vlogTitle).foregroundStyle(Color.chalk)
            VStack(spacing: Space.xs) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        Haptics.tap()
                        picked = language
                        state.setLanguage(language)
                    } label: {
                        HStack {
                            Text(verbatim: language.nativeName)
                                .font(.vlogLabel)
                                .foregroundStyle(Color.chalk)
                            Spacer()
                            if picked == language {
                                Image(systemName: "checkmark").foregroundStyle(Color.orchidInk)
                            }
                        }
                        .padding(.horizontal, Space.md)
                        .frame(height: 56)
                        .background(picked == language ? Color.orchid.opacity(0.25) : Color.surface,
                                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                            .stroke(picked == language ? Color.orchid : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("language.\(language.rawValue)")
                    .accessibilityAddTraits(picked == language ? .isSelected : [])
                }
            }
            Spacer()
            if !isChanging {
                PillButton(title: "continue", style: .accent) {
                    state.setLanguage(picked)
                    state.languageChosen = true
                }
                .accessibilityIdentifier("language.continue")
            }
        }
        .padding(Space.gutter)
        .padding(.top, Space.md)
        .background(Color.ink.ignoresSafeArea())
        .screen("screen.language")
    }
}
