import SwiftUI
import VlogifyDesign

// Renders the 1024 app icon from the same mascot shape the welcome screen draws.
// `swift run IconSheet out.png`. Opaque on purpose: App Review rejects an icon with
// an alpha channel, and the butter cloud on ink is the brand.
@MainActor
func render() {
    let path = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
    let view = ZStack {
        Color.ink
        MascotShape()
            .fill(Color.sand)
            .frame(width: 760, height: 660)
            .offset(y: 30)
        MascotShape()
            .stroke(Color.text, lineWidth: 18)
            .frame(width: 760, height: 660)
            .offset(y: 30)
        // Eyes and smile, big enough to read at 32pt.
        HStack(spacing: 60) {
            eye
            eye
        }
        .offset(y: -20)
        SmilePath()
            .stroke(Color.text, style: StrokeStyle(lineWidth: 22, lineCap: .round))
            .frame(width: 180, height: 70)
            .offset(y: 120)
    }
    .frame(width: 1024, height: 1024)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    // Opaque: App Review rejects an icon with an alpha channel.
    renderer.isOpaque = true
    #if canImport(AppKit)
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("render failed"); exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print(path)
    #endif
}

var eye: some View {
    Circle().fill(Color.card)
        .overlay(Circle().stroke(Color.text, lineWidth: 16))
        .overlay(Circle().fill(Color.text).frame(width: 64, height: 64).offset(x: 12))
        .frame(width: 130, height: 130)
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.8))
        return path
    }
}

render()
