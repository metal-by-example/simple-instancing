
import Foundation
import MetalKit

extension simd_float4x4 {
    init(orthographicProjectionWithLeft left: Float, top: Float, right: Float, bottom: Float, near: Float, far: Float) {
        let xs = 2 / (right - left)
        let ys = 2 / (top - bottom)
        let zs = 1 / (near - far)
        let tx = (left + right) / (left - right)
        let ty = (top + bottom) / (bottom - top)
        let tz = near / (near - far)
        self.init(columns: (simd_float4(xs,  0,  0, 0),
                            simd_float4( 0, ys,  0, 0),
                            simd_float4( 0,  0, zs, 0),
                            simd_float4(tx, ty, tz, 1)))
    }
}

class Renderer : NSObject, MTKViewDelegate {
    static let maxFramesInFlight = 3
    
    let view: MTKView
    let device: MTLDevice
    let commandQueue: MTLCommandQueue!
    let frameSemaphore = DispatchSemaphore(value: Renderer.maxFramesInFlight)
    
    var renderPipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var instanceBuffers: [MTLBuffer] = []
    var frameIndex = 0
    var scene: Scene!

    init(view: MTKView) {
        guard let device = view.device else {
            fatalError("MTKView should be configured with a device before creating a renderer")
        }
        
        self.view = view
        self.device = device
        commandQueue = device.makeCommandQueue()!
        
        super.init()

        self.view.delegate = self

        makePipeline()
        makeResources()
    }
    
    func makePipeline() {
        let library = device.makeDefaultLibrary()!
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        renderPipelineDescriptor.rasterSampleCount = view.sampleCount
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        if USE_VERTEX_DESCRIPTOR == 1 {
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2 // vertex position
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0

            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 2
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            vertexDescriptor.layouts[0].stepRate = 1

            vertexDescriptor.attributes[1].format = .float2 // instance position
            vertexDescriptor.attributes[1].bufferIndex = 1
            vertexDescriptor.attributes[1].offset = 0

            vertexDescriptor.attributes[2].format = .float // instance radius
            vertexDescriptor.attributes[2].bufferIndex = 1
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 2

            vertexDescriptor.attributes[3].format = .float3 // instance color
            vertexDescriptor.attributes[3].bufferIndex = 1
            vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 3

            vertexDescriptor.layouts[1].stride = MemoryLayout<Float>.stride * 6
            vertexDescriptor.layouts[1].stepFunction = .perInstance
            vertexDescriptor.layouts[1].stepRate = 1

            renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        }

        renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func makeResources() {
        let size = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        
        scene = Scene(sceneSize: size, shapeCount: 128)
        
        vertexBuffer = device.makeBuffer(length: Shape.vertexDataLength, options: [.storageModeShared])
        Shape.copyVertexData(to: vertexBuffer)
        
        instanceBuffers = []
        for _ in 0..<Renderer.maxFramesInFlight {
            if let buffer = device.makeBuffer(length: Shape.instanceDataLength, options: [.storageModeShared]) {
                instanceBuffers.append(buffer)
            }
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        makeResources()
        frameIndex = 0
    }
    
    func draw(in view: MTKView) {
        frameSemaphore.wait()
        
        scene.update(with: TimeInterval(1 / 60.0))
        
        scene.copyInstanceData(to: instanceBuffers[frameIndex])
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        defer {
            commandBuffer.commit()
        }
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(instanceBuffers[frameIndex], offset: 0, index: 1)
        
        var projectionMatrix = simd_float4x4(orthographicProjectionWithLeft: 0.0,
                                             top: 0.0,
                                             right: Float(view.drawableSize.width),
                                             bottom: Float(view.drawableSize.height),
                                             near: 0.0,
                                             far: 1.0)
        renderCommandEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout.size(ofValue: projectionMatrix), index: 2)
        
        renderCommandEncoder.drawPrimitives(type: .triangle,
                                            vertexStart: 0,
                                            vertexCount: Shape.sideCount * 3,
                                            instanceCount: scene.shapes.count)
        
        renderCommandEncoder.endEncoding()
        
        view.currentDrawable!.present()
        
        commandBuffer.addCompletedHandler { _ in
            self.frameSemaphore.signal()
        }
        
        frameIndex = (frameIndex + 1) % Renderer.maxFramesInFlight
    }
}
