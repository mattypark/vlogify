import AVFoundation
import SwiftUI
import VlogifyDesign

/// The live preview, or a placeholder in the simulator.
struct CameraPreview: View {
    let camera: CameraSession

    var body: some View {
        if camera.isSimulated {
            ZStack {
                LinearGradient(colors: [Color(OKLCH(0.35, 0.03, 60)), Color(OKLCH(0.22, 0.02, 280))],
                               startPoint: .top, endPoint: .bottom)
                VStack {
                    Spacer()
                    Text("no camera in the simulator")
                        .font(.vlogCaption)
                        .foregroundStyle(Color.chalkSoft)
                        .padding(.bottom, 150)
                }
            }
            .accessibilityIdentifier("camera.preview.simulated")
        } else {
            PreviewLayerView(session: camera.session)
                .accessibilityIdentifier("camera.preview")
        }
    }
}

private struct PreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
