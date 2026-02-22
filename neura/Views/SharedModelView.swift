import SwiftUI
#if os(iOS)
import RealityKit
import Combine

// MARK: - SharedModelView

struct SharedModelView: UIViewRepresentable {
    let modelName: String

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)
        arView.environment.lighting.intensityExponent = 1.5

        let cachedEntity = ModelCache.shared.get(modelName)
        let model: Entity
        if let cached = cachedEntity {
            model = cached
        } else if let url = Bundle.main.url(forResource: modelName, withExtension: "usdz"),
                  let loaded = try? Entity.load(contentsOf: url) {
            model = loaded
        } else {
            return arView
        }

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(model)
        arView.scene.addAnchor(anchor)

        let bounds = model.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        let baseScale = maxDim > 0 ? Float(0.35 / maxDim) : 1.0
        model.scale    = SIMD3<Float>(repeating: baseScale)
        model.position = SIMD3<Float>(-bounds.center.x * baseScale,
                                       -bounds.center.y * baseScale,
                                       -0.45)

        let coord = context.coordinator
        coord.modelEntity = model
        coord.baseScale = baseScale

        var elapsed: Float = 0
        arView.scene.subscribe(to: SceneEvents.Update.self) { ev in
            guard !coord.isTouching else { return }
            elapsed += Float(ev.deltaTime) * 0.35
            model.transform.rotation = simd_quatf(angle: elapsed, axis: [0, 1, 0])
        }.store(in: &coord.bag)

        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 28
        let camAnchor = AnchorEntity(world: [0, 0, 0.55])
        camAnchor.addChild(cam)
        arView.scene.addAnchor(camAnchor)

        let pan = UIPanGestureRecognizer(target: coord, action: #selector(SharedModelCoordinator.handlePan(_:)))
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: coord, action: #selector(SharedModelCoordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
    func makeCoordinator() -> SharedModelCoordinator { SharedModelCoordinator() }
}

// MARK: - Coordinator

class SharedModelCoordinator: NSObject {
    var bag = Set<AnyCancellable>()
    var modelEntity: Entity?
    var baseScale: Float = 1.0
    var isTouching = false

    private var rotationX: Float = 0
    private var rotationY: Float = 0
    private var currentZoom: Float = 1.0

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let model = modelEntity else { return }
        switch gesture.state {
        case .began:
            isTouching = true
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            rotationY += Float(translation.x) * 0.008
            rotationX += Float(translation.y) * 0.008
            rotationX = min(max(rotationX, -.pi / 3), .pi / 3)
            let qX = simd_quatf(angle: rotationX, axis: [1, 0, 0])
            let qY = simd_quatf(angle: rotationY, axis: [0, 1, 0])
            model.transform.rotation = qY * qX
            gesture.setTranslation(.zero, in: gesture.view)
        case .ended, .cancelled:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isTouching = false
            }
        default: break
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let model = modelEntity else { return }
        switch gesture.state {
        case .began:
            isTouching = true
        case .changed:
            currentZoom = min(max(Float(gesture.scale) * currentZoom, 0.5), 3.0)
            model.scale = SIMD3<Float>(repeating: baseScale * currentZoom)
            gesture.scale = 1.0
        case .ended, .cancelled:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isTouching = false
            }
        default: break
        }
    }
}
#endif
