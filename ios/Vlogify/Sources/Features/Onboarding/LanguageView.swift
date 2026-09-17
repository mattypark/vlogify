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
                .font(.vlogTitle).foregroundStyle(Color.text)
            Text(verbatim: "언어 · 言語 · 語言 · ngôn ngữ · язык")
                .font(.vlogCaption).foregroundStyle(Color.textSoft)
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
                                .foregroundStyle(Color.text)
                            Spacer()
                            if picked == language {
                                Image(systemName: "checkmark").font(Font.system(size: 16, weight: .black)).foregroundStyle(Color.text)
                            }
                        }
                        .padding(.horizontal, Space.md)
                        .frame(height: 52)
                    }
                    .buttonStyle(StickerButtonStyle(fill: picked == language ? Color(Palette.playful(index: AppLanguage.allCases.firstIndex(of: language) ?? 0).color) : .card, radius: Radius.row))
                    .stickerRoom()
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
        .background(Color.ground.ignoresSafeArea())
        .tapBursts()
        .screen("screen.language")
    }
}
