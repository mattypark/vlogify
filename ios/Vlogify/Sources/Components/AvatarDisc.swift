import SwiftUI
import VlogifyContract
import VlogifyDesign

/// Two lowercase letters on a colour drawn from the profile's seed. No photos: the
/// clips are the faces.
struct AvatarDisc: View {
    let profile: Profile
    var size: CGFloat = Metrics.avatar

    var body: some View {
        Text(verbatim: String(profile.displayName.prefix(2)).lowercased())
            .font(Font.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ink)
            .frame(width: size, height: size)
            .background(Color.avatar(seed: profile.avatarSeed), in: Circle())
            .accessibilityLabel(Text(verbatim: profile.displayName))
    }
}
