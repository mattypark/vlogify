import SwiftUI

/// Every illustration in the app, as a slot.
///
/// The artist has not drawn anything yet. Rather than bake in a placeholder that then
/// has to be found and replaced, each drawing has a name, a home, and a size, and the
/// view asks for the slot. If `Doodles/<name>.png` exists in the asset catalogue it is
/// used; otherwise the slot draws a flat shape of the right footprint so the layout is
/// real even while the art is not. `docs/ART-SLOTS.md` is generated from this list.
public enum Doodle: String, CaseIterable, Sendable {
    // Welcome page
    case mascot, starHappy, starSurprised, sparkleSmall, sparkleLarge, moon, envelope
    case pizza, orange, plant, tea, flames, sundae
    // Home
    case turtle, ufo
    // Room-type cards
    case glyphLog, glyphStack, glyphVlog
    // Camera
    case shutterSmile

    /// The design size in points, at the place the doodle is used.
    public var size: CGSize {
        switch self {
        case .mascot: return CGSize(width: 180, height: 160)
        case .starHappy, .starSurprised: return CGSize(width: 76, height: 76)
        case .sparkleSmall: return CGSize(width: 24, height: 24)
        case .sparkleLarge: return CGSize(width: 40, height: 40)
        case .moon: return CGSize(width: 84, height: 84)
        case .envelope: return CGSize(width: 70, height: 56)
        case .pizza: return CGSize(width: 110, height: 96)
        case .orange: return CGSize(width: 48, height: 52)
        case .plant: return CGSize(width: 190, height: 170)
        case .tea: return CGSize(width: 96, height: 140)
        case .flames: return CGSize(width: 96, height: 60)
        case .sundae: return CGSize(width: 90, height: 130)
        case .turtle: return CGSize(width: 78, height: 44)
        case .ufo: return CGSize(width: 110, height: 78)
        case .glyphLog, .glyphStack, .glyphVlog: return CGSize(width: 64, height: 120)
        case .shutterSmile: return CGSize(width: 84, height: 84)
        }
    }

    /// Where it appears, for the artist's brief.
    public var placement: String {
        switch self {
        case .mascot: return "Welcome, centre. The app icon too."
        case .starHappy: return "Welcome, top-left of the mascot."
        case .starSurprised: return "Welcome, top-right of the mascot."
        case .sparkleSmall, .sparkleLarge: return "Welcome, scattered around the top."
        case .moon: return "Welcome, right of the mascot, asleep."
        case .envelope: return "Welcome, left of the mascot, with a heart."
        case .pizza: return "Welcome, left, under the tagline."
        case .orange: return "Welcome, centre, under the tagline."
        case .plant: return "Welcome, right, under the tagline, in a pot."
        case .tea: return "Welcome, bottom-left, a mug that says tea."
        case .flames: return "Welcome, bottom-centre, three small flames."
        case .sundae: return "Welcome, bottom-right."
        case .turtle: return "Home, empty state, bottom-left, walking."
        case .ufo: return "Home, empty state, bottom-right, an alien waving."
        case .glyphLog: return "New room sheet: three stacked clips labelled 12:00."
        case .glyphStack: return "New room sheet: one tall clip labelled 12:00."
        case .glyphVlog: return "New room sheet: one small clip labelled 12:00."
        case .shutterSmile: return "Camera: the shutter. A smiley face on a sky disc."
        }
    }

    /// The asset name the artist's file must have.
    public var assetName: String { "Doodles/\(rawValue)" }

    /// The stand-in color while the art is missing.
    var placeholderColor: Color {
        switch self {
        case .mascot, .starHappy, .starSurprised, .sparkleSmall, .sparkleLarge, .moon, .sundae:
            return .butter
        case .shutterSmile: return .sky
        case .plant, .turtle: return Color(OKLCH(0.75, 0.13, 145))
        case .pizza, .orange, .flames: return .ember
        case .tea, .ufo, .envelope: return Color(OKLCH(0.72, 0.14, 300))
        case .glyphLog, .glyphStack, .glyphVlog: return .surfaceRaised
        }
    }
}

/// Draws a doodle slot: the artist's PNG if it is in the bundle, a flat placeholder
/// of the same footprint if not.
public struct DoodleSticker: View {
    let doodle: Doodle
    let scale: CGFloat

    public init(_ doodle: Doodle, scale: CGFloat = 1) {
        self.doodle = doodle
        self.scale = scale
    }

    public var body: some View {
        let size = CGSize(width: doodle.size.width * scale, height: doodle.size.height * scale)
        Group {
            #if canImport(UIKit)
            if let image = UIImage(named: doodle.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                DoodlePlaceholder(doodle: doodle)
            }
            #else
            DoodlePlaceholder(doodle: doodle)
            #endif
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

/// A recognisable stand-in, not a grey box: the mascot is a cloud with a face because
/// the layout has to be judged with something cloud-shaped in it.
struct DoodlePlaceholder: View {
    let doodle: Doodle

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            switch doodle {
            case .mascot:
                MascotShape().fill(doodle.placeholderColor)
                    .overlay(MascotShape().stroke(Color.soot, lineWidth: max(2, w * 0.018)))
                    .overlay(Face(eyeSize: w * 0.13).offset(y: -h * 0.04))
            case .shutterSmile:
                Circle().fill(doodle.placeholderColor)
                    .overlay(Circle().stroke(Color(OKLCH(0.45, 0.2, 265)), lineWidth: max(3, w * 0.05)))
                    .overlay(Face(eyeSize: w * 0.09).offset(y: -h * 0.02))
            case .starHappy, .starSurprised, .sparkleSmall, .sparkleLarge:
                StarShape(points: doodle == .sparkleSmall || doodle == .sparkleLarge ? 4 : 5)
                    .fill(doodle.placeholderColor)
                    .overlay(StarShape(points: 5).stroke(Color.soot, lineWidth: doodle.size.width > 40 ? 2 : 0))
            case .moon:
                Circle().fill(doodle.placeholderColor)
                    .overlay(Circle().fill(Color.paper).offset(x: -w * 0.28, y: -h * 0.12))
            case .glyphLog:
                VStack(spacing: h * 0.06) {
                    ForEach(0..<3, id: \.self) { _ in glyphClip(width: w * 0.8, height: h * 0.26) }
                }
                .frame(width: w, height: h)
            case .glyphStack:
                glyphClip(width: w * 0.9, height: h * 0.96).frame(width: w, height: h)
            case .glyphVlog:
                glyphClip(width: w * 0.8, height: h * 0.34).frame(width: w, height: h)
            default:
                RoundedRectangle(cornerRadius: min(w, h) * 0.3, style: .continuous)
                    .fill(doodle.placeholderColor)
                    .overlay(RoundedRectangle(cornerRadius: min(w, h) * 0.3, style: .continuous)
                        .stroke(Color.soot.opacity(0.7), lineWidth: 2))
            }
        }
    }

    func glyphClip(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
            .fill(Color.surfaceRaised)
            .overlay(Text("12:00").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(Color.chalk))
            .frame(width: width, height: height)
    }
}

/// Two eyes and a smile. The whole personality budget.
struct Face: View {
    let eyeSize: CGFloat

    var body: some View {
        VStack(spacing: eyeSize * 0.2) {
            HStack(spacing: eyeSize * 0.5) {
                eye
                eye
            }
            SmileShape().stroke(Color.soot, style: StrokeStyle(lineWidth: max(2, eyeSize * 0.16), lineCap: .round))
                .frame(width: eyeSize * 1.6, height: eyeSize * 0.6)
        }
    }

    var eye: some View {
        Circle().fill(Color.paper)
            .overlay(Circle().stroke(Color.soot, lineWidth: max(1.5, eyeSize * 0.12)))
            .overlay(Circle().fill(Color.soot).frame(width: eyeSize * 0.5, height: eyeSize * 0.5).offset(x: eyeSize * 0.1))
            .frame(width: eyeSize, height: eyeSize)
    }
}

public struct MascotShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        // A cloud: five overlapping circles inside a rounded base.
        var path = Path()
        let w = rect.width, h = rect.height
        let bumps: [(CGFloat, CGFloat, CGFloat)] = [
            (0.30, 0.55, 0.30), (0.52, 0.38, 0.34), (0.74, 0.55, 0.28),
            (0.42, 0.68, 0.30), (0.62, 0.72, 0.26),
        ]
        for (cx, cy, r) in bumps {
            path.addEllipse(in: CGRect(x: w * (cx - r / 2), y: h * (cy - r / 2 * (w / h)),
                                       width: w * r, height: w * r))
        }
        return path
    }
}

public struct StarShape: Shape {
    let points: Int

    public init(points: Int) { self.points = points }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * (points == 4 ? 0.28 : 0.5)
        for index in 0..<(points * 2) {
            let angle = (Double(index) / Double(points * 2)) * 2 * .pi - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}
