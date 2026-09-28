import SwiftUI
import VlogifyDesign

// Renders the 1024 app icon with the same pen the app draws with.
// `swift run IconSheet out.png [--favicon]`. Opaque on purpose: App Review rejects an
// icon with an alpha channel.
//
// A record button, drawn by hand: one loose pen loop on paper, and inside it the only
// colour vlogify ever uses -- the red of "recording". It reads at 29pt as a record
// button, and up close as a drawing, which is the whole app in one mark.
@MainActor
func render() {
    let path = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
    let view = ZStack {
        Color.ground
        PenShape(.circle, seed: 7, wobble: 10)
            .stroke(Color.text, style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round))
            .frame(width: 700, height: 700)
        BlobShape(seed: 11, points: 9, wobble: 0.08)
            .fill(Color.recording)
            .frame(width: 330, height: 330)
            .offset(x: 6, y: 4)
    }
    .frame(width: 1024, height: 1024)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
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

render()
