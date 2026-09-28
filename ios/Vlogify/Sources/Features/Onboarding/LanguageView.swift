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
            HandwrittenText(text: "choose your language", font: .vlogTitle, delay: 0.1)
            HandwrittenText(text: "언어 · 言語 · 語言 · ngôn ngữ · язык", font: .vlogCaption, color: .textSoft, delay: 0.4)
            VStack(spacing: Space.xs) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
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
                                DoodleSticker(.check, scale: 1.1, lineWidth: 2.4)
                            }
                        }
                        .padding(.horizontal, Space.md)
                        .frame(height: 52)
                    }
                    // Rows trace themselves in one after another, top to bottom.
                    .buttonStyle(StickerButtonStyle(fill: picked == language ? .fog : .card, radius: Radius.row,
                                                    drawIn: isChanging ? nil : 0.6 + Double(index) * 0.12))
                    .stickerRoom()
                    .accessibilityIdentifier("language.\(language.rawValue)")
                    .accessibilityAddTraits(picked == language ? .isSelected : [])
                }
            }
            Spacer()
            if !isChanging {
                PillButton(title: "continue", style: .accent, drawIn: 0.6 + Double(AppLanguage.allCases.count) * 0.12) {
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
