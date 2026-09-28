import Foundation
import Observation
import VlogifyEngine

/// Which way clips are shot, app-wide. Landscape by default: most people turn the
/// phone, and landscape clips stack cleanly when a room stitches. Changing it moves
/// the hour stamp, the "turn me sideways" hint, and the stitched layout together --
/// never one without the others.
@MainActor
@Observable
final class CapturePreferences {
    private static let key = "captureOrientation"
    private static let fontKey = "stampFont"

    var orientation: StitchPlan.Orientation {
        didSet { UserDefaults.standard.set(orientation.rawValue, forKey: Self.key) }
    }

    /// The face the hour is stamped in, on the camera and burned into the export.
    var stampFont: StampFont {
        didSet { UserDefaults.standard.set(stampFont.rawValue, forKey: Self.fontKey) }
    }

    init() {
        orientation = UserDefaults.standard.string(forKey: Self.key)
            .flatMap(StitchPlan.Orientation.init(rawValue:)) ?? .landscape
        stampFont = UserDefaults.standard.string(forKey: Self.fontKey)
            .flatMap(StampFont.init(rawValue:)) ?? .hand
    }

    func shuffleFont() {
        let all = StampFont.allCases
        let next = all[(all.firstIndex(of: stampFont).map { $0 + 1 } ?? 0) % all.count]
        stampFont = next
    }

    var isLandscape: Bool { orientation == .landscape }

    func toggle() {
        orientation = isLandscape ? .portrait : .landscape
    }
}

/// The looks the hour can wear. The pen hand by default, then system designs and one
/// more bundled face -- every one resolves to a `CTFont` for the export.
enum StampFont: String, CaseIterable, Sendable {
    case hand, bagel, rounded, serif, mono, condensed, wide, italic, heavy

    var label: String {
        switch self {
        case .hand: return "Aa"
        case .bagel: return "Aa"
        case .rounded: return "Aa"
        case .serif: return "Aa"
        case .mono: return "Aa"
        case .condensed: return "Aa"
        case .wide: return "Aa"
        case .italic: return "Aa"
        case .heavy: return "Aa"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .hand: return Typography.handFont(size: size)
        case .bagel: return .custom(Typeface.bagel, size: size)
        case .rounded: return .system(size: size, weight: .heavy, design: .rounded)
        case .serif: return .system(size: size, weight: .black, design: .serif)
        case .mono: return .system(size: size, weight: .bold, design: .monospaced)
        case .condensed: return Font(UIFont.systemFont(ofSize: size, weight: .heavy, width: .condensed))
        case .wide: return Font(UIFont.systemFont(ofSize: size, weight: .heavy, width: .expanded))
        case .italic: return .system(size: size, weight: .bold, design: .serif).italic()
        case .heavy: return .system(size: size, weight: .black)
        }
    }

    /// The same face for CoreAnimation.
    func ctFont(size: CGFloat) -> CTFont {
        let ui: UIFont
        switch self {
        case .hand: ui = Typography.handUIFont(size: size) ?? .systemFont(ofSize: size, weight: .medium)
        case .bagel: ui = UIFont(name: Typeface.bagel, size: size) ?? .systemFont(ofSize: size, weight: .black)
        case .rounded: ui = UIFont.systemFont(ofSize: size, weight: .heavy).withDesign(.rounded)
        case .serif: ui = UIFont.systemFont(ofSize: size, weight: .black).withDesign(.serif)
        case .mono: ui = UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
        case .condensed: ui = UIFont.systemFont(ofSize: size, weight: .heavy, width: .condensed)
        case .wide: ui = UIFont.systemFont(ofSize: size, weight: .heavy, width: .expanded)
        case .italic: ui = UIFont.systemFont(ofSize: size, weight: .bold).withDesign(.serif).withTraits(.traitItalic)
        case .heavy: ui = UIFont.systemFont(ofSize: size, weight: .black)
        }
        return ui as CTFont
    }
}

private extension UIFont {
    func withDesign(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits)) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

import SwiftUI
import UIKit
import VlogifyDesign
