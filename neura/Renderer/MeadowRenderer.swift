import Metal
import MetalKit
import QuartzCore

final class MeadowRenderer: NSObject, MTKViewDelegate {

    // MARK: - Metal objects

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // MARK: - Triple-buffered uniforms

    private static let maxBuffersInFlight = 3
    private let uniformBuffers: [MTLBuffer]
    private var currentBufferIndex = 0
    private let frameSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    // MARK: - Timing

    private var startTime: Double = CACurrentMediaTime()

    // MARK: - Init

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.noCommandQueue
        }
        self.commandQueue = queue

        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.noDefaultLibrary
        }
        guard let vertFn = library.makeFunction(name: "meadowVertex"),
              let fragFn = library.makeFunction(name: "meadowFragment") else {
            throw RendererError.missingShaderFunction
        }

        // Build pipeline
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertFn
        desc.fragmentFunction = fragFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)

        // Allocate triple-buffered uniform buffers
        let bufSize = MemoryLayout<MeadowUniforms>.size
        var buffers: [MTLBuffer] = []
        for _ in 0..<Self.maxBuffersInFlight {
            guard let buf = device.makeBuffer(length: bufSize, options: .storageModeShared) else {
                throw RendererError.noUniformBuffer
            }
            buffers.append(buf)
        }
        self.uniformBuffers = buffers

        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        frameSemaphore.wait()
        currentBufferIndex = (currentBufferIndex + 1) % Self.maxBuffersInFlight
        let uniformBuffer = uniformBuffers[currentBufferIndex]

        // Update uniforms
        let time = Float(CACurrentMediaTime() - startTime)
        let size = view.drawableSize
        var uniforms = MeadowUniforms(
            time: time,
            resolution: simd_float2(Float(size.width), Float(size.height)),
            windSpeed: 0.6,
            windStrength: 0.03,
            dayTime: 0.5
        )
        withUnsafeBytes(of: &uniforms) { bytes in
            uniformBuffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        }

        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
        else {
            frameSemaphore.signal()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        let sem = frameSemaphore
        cmdBuf.addCompletedHandler { _ in sem.signal() }
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}

// MARK: - Errors

enum RendererError: Error {
    case noCommandQueue
    case noDefaultLibrary
    case missingShaderFunction
    case noUniformBuffer
}
