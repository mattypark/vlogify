import AVFoundation
import UIKit
import VlogifyContract
import VlogifyEngine

/// Turns a day's clips into one video, laid out by `StitchPlan`.
///
/// One video track per member. Each posted hour is a segment; each member's clip for
/// that hour is inserted into their track at the segment's start, scaled to their
/// tile. An empty tile is simply no video there, and the overlay draws the member's
/// avatar disc in its place so the viewer knows who was missing rather than seeing
/// black. The hour label is a CoreAnimation text layer that fades in per segment.
struct DayCompositor {
    struct Input {
        let log: DayLog
        /// Local file for each clip. Missing entries are treated as not posted.
        let files: [ClipID: URL]
        let clipDuration: Double
    }

    enum Failure: Error { case noClips, exportFailed }

    let renderSize = CGSize(width: StitchPlan.exportWidth, height: StitchPlan.exportHeight)

    func export(_ input: Input, to destination: URL) async throws -> URL {
        let members = input.log.members
        let plan = StitchPlan(memberCount: max(1, members.count))
        let segments = StitchPlan.segments(for: input.log.postedSlots, clipDuration: input.clipDuration)
        guard !segments.isEmpty else { throw Failure.noClips }

        let composition = AVMutableComposition()
        var videoTracks: [AVMutableCompositionTrack] = []
        var audioTracks: [AVMutableCompositionTrack] = []
        for _ in members.indices {
            guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { throw Failure.exportFailed }
            videoTracks.append(video)
            audioTracks.append(audio)
        }

        // Per track, the transform that maps the source into its tile. A track keeps
        // one transform for the whole day because the tile does not move.
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var tileTransforms: [Int: CGAffineTransform] = [:]

        for segment in segments {
            let start = CMTime(seconds: segment.start, preferredTimescale: 600)
            for (index, member) in members.enumerated() {
                guard let clip = input.log.clip(from: member.userID, in: segment.slot),
                      let file = input.files[clip.id] else { continue }
                let asset = AVURLAsset(url: file)
                guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else { continue }
                let duration = try await asset.load(.duration)
                let range = CMTimeRange(start: .zero, duration: min(duration, CMTime(seconds: segment.duration, preferredTimescale: 600)))
                try videoTracks[index].insertTimeRange(range, of: sourceVideo, at: start)
                if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                    try? audioTracks[index].insertTimeRange(range, of: sourceAudio, at: start)
                }
                if tileTransforms[index] == nil {
                    let natural = try await sourceVideo.load(.naturalSize)
                    let preferred = try await sourceVideo.load(.preferredTransform)
                    tileTransforms[index] = transform(naturalSize: natural, preferredTransform: preferred, tile: plan.tiles[index])
                }
            }
        }

        for (index, track) in videoTracks.enumerated() {
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            instruction.setTransform(tileTransforms[index] ?? .identity, at: .zero)
            layerInstructions.append(instruction)
        }

        let total = CMTime(seconds: StitchPlan.totalDuration(slotCount: segments.count, clipDuration: input.clipDuration), preferredTimescale: 600)
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: total)
        mainInstruction.layerInstructions = layerInstructions
        mainInstruction.backgroundColor = UIColor(Color.ink).cgColor

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [mainInstruction]
        videoComposition.animationTool = overlayTool(segments: segments, members: members, plan: plan, log: input.log)

        try? FileManager.default.removeItem(at: destination)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.exportFailed
        }
        session.videoComposition = videoComposition
        try await session.export(to: destination, as: .mp4)
        return destination
    }

    /// Aspect-fill a source (with its recorded rotation applied) into a tile.
    func transform(naturalSize: CGSize, preferredTransform: CGAffineTransform, tile: StitchPlan.Tile) -> CGAffineTransform {
        let oriented = naturalSize.applying(preferredTransform)
        let sourceWidth = abs(oriented.width), sourceHeight = abs(oriented.height)
        let tileRect = CGRect(x: tile.x * renderSize.width, y: tile.y * renderSize.height,
                              width: tile.width * renderSize.width, height: tile.height * renderSize.height)
        let scale = max(tileRect.width / sourceWidth, tileRect.height / sourceHeight)
        let scaledWidth = sourceWidth * scale, scaledHeight = sourceHeight * scale
        let offsetX = tileRect.minX + (tileRect.width - scaledWidth) / 2
        let offsetY = tileRect.minY + (tileRect.height - scaledHeight) / 2
        // preferredTransform can translate by the natural size (a rotated source);
        // normalise it back to the origin before scaling into the tile.
        let bounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let normalised = preferredTransform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
        return normalised
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }

    /// Hour labels and missing-member discs, as CoreAnimation over the video.
    func overlayTool(segments: [StitchPlan.Segment], members: [Membership], plan: StitchPlan, log: DayLog) -> AVVideoCompositionCoreAnimationTool {
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)
        // CoreAnimation's y axis is flipped relative to the video's.
        parent.isGeometryFlipped = true

        for segment in segments {
            let begin = segment.start == 0 ? AVCoreAnimationBeginTimeAtZero : segment.start
            let label = CATextLayer()
            label.string = segment.slot.label
            label.font = UIFont.systemFont(ofSize: 96, weight: .heavy).fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 96) } ?? UIFont.systemFont(ofSize: 96, weight: .heavy)
            label.fontSize = 96
            label.foregroundColor = UIColor.white.cgColor
            label.shadowColor = UIColor.black.cgColor
            label.shadowOpacity = 0.5
            label.shadowRadius = 8
            label.alignmentMode = .center
            label.contentsScale = 2
            label.frame = CGRect(x: 0, y: renderSize.height - 260, width: renderSize.width, height: 120)
            label.opacity = 0
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.08, 0.92, 1]
            fade.beginTime = begin
            fade.duration = segment.duration
            fade.isRemovedOnCompletion = false
            fade.fillMode = .forwards
            label.add(fade, forKey: "fade")
            parent.addSublayer(label)

            for (index, member) in members.enumerated() where log.clip(from: member.userID, in: segment.slot) == nil {
                let tile = plan.tiles[index]
                let disc = CATextLayer()
                disc.string = String(member.profile.displayName.prefix(2)).lowercased()
                disc.fontSize = 44
                disc.alignmentMode = .center
                disc.contentsScale = 2
                disc.foregroundColor = UIColor.white.cgColor
                disc.backgroundColor = UIColor(Color.avatar(seed: member.profile.avatarSeed)).cgColor
                disc.cornerRadius = 50
                let center = CGPoint(x: (tile.x + tile.width / 2) * renderSize.width, y: (tile.y + tile.height / 2) * renderSize.height)
                disc.frame = CGRect(x: center.x - 50, y: center.y - 50, width: 100, height: 100)
                disc.opacity = 0
                let show = CAKeyframeAnimation(keyPath: "opacity")
                show.values = [0, 1, 1, 0]
                show.keyTimes = [0, 0.01, 0.99, 1]
                show.beginTime = begin
                show.duration = segment.duration
                show.isRemovedOnCompletion = false
                show.fillMode = .forwards
                disc.add(show, forKey: "show")
                parent.addSublayer(disc)
            }
        }
        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
    }
}

import SwiftUI
import VlogifyDesign
