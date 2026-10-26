import AVKit
import SwiftUI
import VlogifyContract
import VlogifyDesign

/// One member's clip for one hour: a thumbnail that plays when tapped, or the
/// member's mark, faint, on the page when they missed it. Every tile carries its
/// owner's mark in the corner -- that is how you tell whose two seconds these were.
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
                HStack(spacing: Space.xxs) {
                    if clip != nil {
                        MarkView(mark: member.profile.mark, name: member.profile.displayName, size: 18, color: .text)
                            .padding(3)
                            .background(Color.card, in: Circle())
                    }
                    Text(verbatim: isMe ? String(localized: "you", bundle: .app) : member.profile.displayName)
                        .font(.vlogHandSmall)
                        .foregroundStyle(Color.text)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 1)
                        .background(Color.card.opacity(clip == nil ? 0 : 0.92), in: Capsule())
                    Spacer()
                }
                .padding(Space.xs)
            }
        }
        .frame(height: Metrics.tileHeight)
        // A pen outline. Yours is drawn harder: that is how you find yourself in a room
        // of six. A missed hour is a lighter pencil line.
        .overlay(PenShape(.radius(Radius.tile), wobble: 1)
            .stroke(clip == nil ? Color.hairline : Color.text, style: Ink.style(isMe ? 2.8 : 1.6)))
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
        // The frame comes from the tile, never from the picture: a filled image reports
        // its own (taller) size, and laid out at that size it spills over the hour rows.
        Color.cardRaised
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
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
