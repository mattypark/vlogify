import SwiftUI
import VlogifyDesign

/// The pill bar: a round button either side of the camera/logs toggle. On the logs
/// tab that is bell + plus; on the camera tab it is timer + flip. Same silhouette so
/// the toggle never jumps.
struct BottomBar<Leading: View, Trailing: View>: View {
    @Binding var tab: AppState.Tab
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            leading
            Spacer()
            SegmentToggle(tab: $tab)
            Spacer()
            trailing
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xs)
        .background(Color.ground)
    }
}

/// The `+` menu. Create, join, and -- only when built -- a zip.
struct PlusMenu: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    var onNote: () -> Void = {}

    var body: some View {
        Menu {
            Button(action: onCreate) { Label("create a room", systemImage: "plus.square") }
            Button(action: onJoin) { Label("join with code", systemImage: "number") }
            Button(action: onNote) { Label("add a note", systemImage: "pencil.line") }
            if FeatureFlags.zipPhotos {
                Divider()
                Button {} label: { Label("start a zip", systemImage: "bolt") }
            }
        } label: {
            Image(systemName: "plus")
                .font(Font.system(size: 24, weight: .black))
                .foregroundStyle(Color.soot)
                .frame(width: Metrics.barButton, height: Metrics.barButton)
                .background { Circle().fill(Color.orchid) }
                .overlay { Circle().strokeBorder(Color.soot, lineWidth: Sticker.line) }
                .compositingGroup()
                .shadow(color: Color.soot, radius: 0, x: Sticker.drop, y: Sticker.drop)
        }
        .stickerRoom()
        .accessibilityLabel(Text("new"))
        .accessibilityIdentifier("bar.plus")
    }
}
