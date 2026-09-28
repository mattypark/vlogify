import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Who you are in vlogify: a name, and a mark you draw yourself.
///
/// The mark is the part that is yours alone. It becomes your avatar, the badge on your
/// clips, and the signature on your square of the nightly vlog -- so once it is drawn,
/// onboarding hands the page over to it: it redraws itself big and says hello.
struct ProfileSetupView: View {
    enum Step { case name, draw, meet }

    @Environment(AppState.self) private var state
    @State private var step: Step = .name
    @State private var name = ""
    @State private var strokes: [[CGPoint]] = []
    @State private var busy = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            switch step {
            case .name: nameStep
            case .draw: drawStep
            case .meet: meetStep
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.xxl)
        .padding(.bottom, Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ground.ignoresSafeArea())
        .animation(Motion.shift, value: step)
        .onAppear {
            name = state.profile?.displayName ?? ""
            // Someone who already has a name (a returning account) goes straight to
            // drawing; the name step is only for people who do not have one yet.
            if !trimmed.isEmpty { step = .draw } else { focused = true }
            #if DEBUG
            if let debugStep = LaunchArguments.step, debugStep > 0 {
                if name.isEmpty { name = "matthew" }
                if debugStep == 2 { strokes = Mark.sample(0).points }
                step = debugStep == 1 ? .draw : .meet
            }
            #endif
        }
        .screen("screen.profile")
    }

    // MARK: Steps

    private var nameStep: some View {
        Group {
            Text("what do friends call you?")
                .font(.vlogTitle)
                .foregroundStyle(Color.text)
            Text("it goes under your clips. optional: you can skip it and change it later.")
                .font(.vlogBody)
                .foregroundStyle(Color.textSoft)
            TextField("your name", text: $name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.vlogBody)
                .foregroundStyle(Color.text)
                .focused($focused)
                .submitLabel(.next)
                .onSubmit { toDraw() }
                .onChange(of: name) { _, new in name = String(new.prefix(20)) }
                .padding(Space.md)
                .sticker(fill: .card, radius: Radius.row)
                .padding(.top, Space.xs)
                .accessibilityIdentifier("profile.name")
            Spacer()
            PillButton(title: "next", style: .filled) { toDraw() }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.4 : 1)
                .accessibilityIdentifier("profile.next")
            // A name is optional: Sign in with Apple may already have shared one, or the
            // person may not want to (Guideline 4). The mark is who they are either way.
            Button {
                name = String(localized: "friend", bundle: .app)
                toDraw()
            } label: {
                Text("skip")
                    .font(.vlogLabel)
                    .foregroundStyle(Color.textSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.skipName")
        }
    }

    private var drawStep: some View {
        Group {
            Text("now draw your mark.")
                .font(.vlogTitle)
                .foregroundStyle(Color.text)
            Text("a face, a star, a squiggle, your initial. it signs every clip you take.")
                .font(.vlogBody)
                .foregroundStyle(Color.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            MarkEditor(strokes: $strokes)
                .padding(.top, Space.xs)
            Spacer(minLength: Space.xs)
            PillButton(title: "that's me", style: .filled) {
                Haptics.success()
                step = .meet
            }
            .disabled(strokes.isEmpty)
            .opacity(strokes.isEmpty ? 0.4 : 1)
            .accessibilityIdentifier("profile.drawn")
        }
    }

    private var meetStep: some View {
        Group {
            Spacer()
            HStack {
                Spacer()
                MarkView(mark: Mark(canvas: strokes), name: trimmed, size: 220, animated: true)
                Spacer()
            }
            Text("meet \(trimmed).")
                .font(.vlogHandTitle)
                .foregroundStyle(Color.text)
                .frame(maxWidth: .infinity)
                .padding(.top, Space.lg)
            Text("friends see this on your clips. you can redraw it any time in your profile.")
                .font(.vlogBody)
                .foregroundStyle(Color.textSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            PillButton(title: "let's go", style: .filled, isLoading: busy) { save() }
                .accessibilityIdentifier("profile.save")
            Button { step = .draw } label: {
                Text("draw it again")
                    .font(.vlogLabel)
                    .foregroundStyle(Color.textSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.redraw")
        }
    }

    // MARK: Actions

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func toDraw() {
        guard !trimmed.isEmpty else { return }
        focused = false
        step = .draw
    }

    private func save() {
        busy = true
        Task {
            defer { busy = false }
            do {
                if state.profile?.displayName != trimmed {
                    try await state.saveDisplayName(trimmed)
                }
                // Saved last: the mark is what lets the gate open onto home.
                try await state.saveMark(Mark(canvas: strokes))
                Haptics.success()
            } catch {
                state.show(.error(String(localized: "couldn't save that. try again.", bundle: .app)))
            }
        }
    }
}
