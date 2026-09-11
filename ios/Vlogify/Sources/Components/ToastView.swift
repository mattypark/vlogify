import SwiftUI
import VlogifyDesign

/// One line at the top. Errors are ember, successes are mint-ish chalk, info is chalk.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        Text(verbatim: toast.text)
            .font(.vlogLabel)
            .foregroundStyle(toast.kind == .error ? Color.emberInk : Color.chalk)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.surfaceRaised, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityIdentifier("toast")
    }
}

extension View {
    func toastOverlay(_ toast: Toast?) -> some View {
        overlay(alignment: .top) {
            if let toast {
                ToastView(toast: toast).padding(.top, Space.sm)
            }
        }
        .animation(Motion.shift, value: toast)
    }
}
