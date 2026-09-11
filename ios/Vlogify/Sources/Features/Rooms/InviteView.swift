import SwiftUI
import VlogifyContract
import VlogifyDesign

/// The code, big, with copy and share. Shown right after creating a log and from the
/// room's members row.
struct InviteView: View {
    @Environment(\.dismiss) private var dismiss
    let room: Room
    var done: (() -> Void)? = nil
    @State private var copied = false

    private var link: URL { URL(string: "vlogify://join/\(room.inviteCode.value)")! }

    var body: some View {
        VStack(spacing: Space.lg) {
            Text("invite friends").font(.vlogTitle).foregroundStyle(Color.text)
            Text("anyone with this code can join \(room.name ?? String(localized: "your room", bundle: .app)).")
                .font(.vlogBody).foregroundStyle(Color.textSoft).multilineTextAlignment(.center)
            Text(verbatim: room.inviteCode.formatted)
                .font(.vlogNumeral)
                .tracking(3)
                .foregroundStyle(Color.soot)
                .padding(.vertical, Space.lg)
                .frame(maxWidth: .infinity)
                .sticker(fill: .butter, radius: Radius.sheet)
                .stickerRoom()
                .accessibilityIdentifier("invite.code")
                .accessibilityLabel(Text("invite code \(room.inviteCode.value)"))
            HStack(spacing: Space.sm) {
                PillButton(title: copied ? "copied" : "copy code", icon: "doc.on.doc", style: .outlined) {
                    UIPasteboard.general.string = room.inviteCode.value
                    Haptics.success()
                    copied = true
                }
                .accessibilityIdentifier("invite.copy")
                ShareLink(item: link, message: Text("join my vlogify room: \(room.inviteCode.formatted)")) {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "square.and.arrow.up").font(Font.system(size: 18, weight: .bold))
                        Text("share").font(.vlogShout)
                    }
                    .foregroundStyle(Color.soot)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(StickerButtonStyle(fill: .orchid, radius: Radius.pill))
                .stickerRoom()
                .accessibilityIdentifier("invite.share")
            }
            Spacer()
            Button("done") { done?() ?? dismiss() }
                .font(.vlogLabel).foregroundStyle(Color.text)
                .frame(height: Metrics.hitTarget)
                .accessibilityIdentifier("invite.done")
        }
        .padding(Space.gutter)
        .padding(.top, Space.xl)
        .background(Color.ground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ground)
        .screen("screen.invite")
    }
}
