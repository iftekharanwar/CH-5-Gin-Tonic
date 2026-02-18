import SwiftUI
import MetalKit

// MARK: - Cross-platform MTKView wrapper

#if os(macOS)

struct MeadowView: NSViewRepresentable {

    func makeCoordinator() -> MeadowCoordinator {
        MeadowCoordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        context.coordinator.makeMTKView()
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

#else

struct MeadowView: UIViewRepresentable {

    func makeCoordinator() -> MeadowCoordinator {
        MeadowCoordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        context.coordinator.makeMTKView()
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

#endif

// MARK: - Coordinator

final class MeadowCoordinator: NSObject {

    private var renderer: MeadowRenderer?

    func makeMTKView() -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Fallback: return a plain view if Metal is unavailable
            return MTKView()
        }
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        do {
            let renderer = try MeadowRenderer(device: device)
            view.delegate = renderer
            self.renderer = renderer
        } catch {
            print("[MeadowView] Renderer init failed: \(error)")
        }
        return view
    }
}
