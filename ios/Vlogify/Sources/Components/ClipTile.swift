import AVKit
import SwiftUI
import VlogifyContract
import VlogifyDesign

/// One member's clip for one hour: a thumbnail that plays when tapped, or the
/// member's disc on a dim surface when they missed it.
struct ClipTile: View {
    let member: Membership
    let clip: Clip?
    let isMe: Bool
    let onPlay: (Clip) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(clip == nil ? Color.card : Color.cardRaised)
            if let clip {
                ClipThumbnail(clip: clip)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                Image(systemName: "play.fill")
                    .font(Font.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.chalk)
                    .shadow(radius: 4)
            } else {
                AvatarDisc(profile: member.profile, size: 36).opacity(0.5)
            }
            VStack {
                Spacer()
                HStack {
                    Text(verbatim: isMe ? String(localized: "you", bundle: .app) : member.profile.displayName)
                        .font(.vlogCaption)
                        // chalk, not text: this capsule is 60% ink, so the body colour
                        // only ever read here by accident.
                        .foregroundStyle(Color.chalk)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 3)
                        .background(Color.ink.opacity(0.6), in: Capsule())
                    Spacer()
                }
                .padding(Space.xs)
            }
        }
        .frame(height: Metrics.tileHeight)
        // The member's colour, as the outline. Yours is thicker: that is how you find
        // yourself in a room of six.
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
            .strokeBorder(clip == nil ? Color.hairline : Color.avatar(seed: member.profile.avatarSeed), lineWidth: isMe ? 4 : 2.5))
        .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .onTapGesture { if let clip { onPlay(clip) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(clip == nil ? "\(member.profile.displayName) missed this hour" : "\(member.profile.displayName)'s clip"))
        .accessibilityAddTraits(clip == nil ? [] : .isButton)
    }
}

/// First frame of a clip, generated once and cached by the environment's thumbnailer.
struct ClipThumbnail: View {
    let clip: Clip
    @Environment(Thumbnails.self) private var thumbnails
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.cardRaised
            }
        }
        .task(id: clip.id) { image = await thumbnails.image(for: clip) }
    }
}

/// Generates and caches first frames. One per app; the cache is by clip id.
@MainActor
@Observable
final class Thumbnails {
    private var cache: [ClipID: UIImage] = [:]
    private let media: any MediaStore
    private let local: LocalMediaCache

    init(media: any MediaStore, local: LocalMediaCache) {
        self.media = media
        self.local = local
    }

    func image(for clip: Clip) async -> UIImage? {
        if let cached = cache[clip.id] { return cached }
        guard let url = try? await local.localURL(for: clip, media: media) else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        guard let (cgImage, _) = try? await generator.image(at: CMTime(seconds: 0.4, preferredTimescale: 600)) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache[clip.id] = image
        return image
    }
}
