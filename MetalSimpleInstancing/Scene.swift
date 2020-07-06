
import Foundation
import Cocoa
import simd

func randomInRange(_ lower: Float, _ upperInclusive: Float) -> Float {
    return Float.random(in: lower...upperInclusive)
}

class Shape {
    static let sideCount = 28
    static let vertexDataLength = MemoryLayout<SIMD2<Float>>.stride * 3 * sideCount
    static let instanceDataLength = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<Float>.stride + MemoryLayout<SIMD3<Float>>.stride
    
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var radius: Float
    var color: SIMD3<Float>
    
    init(sceneSize: SIMD2<Float>) {
        position = SIMD2<Float>(Float.random(in: 0.0..<sceneSize.x), Float.random(in: 0.0..<sceneSize.y))
        
        let angle = Float.random(in: 0.0..<(Float.pi * 2))
        let speed = Float.random(in: 10.0...50.0)
        velocity = speed * SIMD2<Float>(cos(angle), sin(angle))

        radius = Float.random(in: 16.0...64.0)
        
        let nsColor = NSColor(calibratedHue: CGFloat(randomInRange(0, 1)),
                              saturation: 0.7,
                              brightness: 1.0,
                              alpha: 1.0)
        var r: CGFloat = 0.0; var g: CGFloat = 0.0; var b: CGFloat = 0.0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        color = SIMD3<Float>(Float(r), Float(g), Float(b))
    }
    
    static func copyVertexData(to buffer: MTLBuffer) {
        let positionData = buffer.contents().bindMemory(to: Float.self,
                                                        capacity: self.vertexDataLength / 4)
        
        let deltaTheta = (Float.pi * 2) / Float(sideCount)
        var i = 0
        for t in 0..<sideCount {
            let t0 = Float(t) * deltaTheta
            let t1 = Float(t + 1) * deltaTheta
            positionData[i] = 0.0; i += 1
            positionData[i] = 0.0; i += 1
            positionData[i] = cos(t0); i += 1
            positionData[i] = sin(t0); i += 1
            positionData[i] = cos(t1); i += 1
            positionData[i] = sin(t1); i += 1
        }
    }
}

class Scene {
    var sceneSize: SIMD2<Float>
    var shapes: [Shape]
    
    init(sceneSize: SIMD2<Float>, shapeCount: Int) {
        self.sceneSize = sceneSize
        shapes = []
        for _ in 0..<shapeCount {
            shapes.append(Shape(sceneSize: sceneSize))
        }
    }
    
    func update(with timestep: TimeInterval) {
        for s in shapes {
            s.position = s.position + (Float(timestep) * s.velocity)
            if s.position.x <= 0.0 {
                s.position.x = 0.0
                if (s.velocity.x < 0.0) {
                    s.velocity.x = -s.velocity.x
                }
            }
            if s.position.y <= 0.0 {
                s.position.y = 0.0
                if (s.velocity.y < 0.0) {
                    s.velocity.y = -s.velocity.y
                }
            }
            if s.position.x >= sceneSize.x {
                s.position.x = sceneSize.x
                if (s.velocity.x > 0.0) {
                    s.velocity.x = -s.velocity.x
                }
            }
            if s.position.y >= sceneSize.y {
                s.position.y = sceneSize.y
                if (s.velocity.y > 0.0) {
                    s.velocity.y = -s.velocity.y
                }
            }
        }
    }
    
    func copyInstanceData(to buffer: MTLBuffer) {
        let instanceData = buffer.contents().bindMemory(to: Float.self,
                                                        capacity: Shape.instanceDataLength / 4 * shapes.count)
        
        var i = 0
        for s in shapes {
            instanceData[i] = s.position.x; i += 1
            instanceData[i] = s.position.y; i += 1
            instanceData[i] = s.radius; i += 1
            instanceData[i] = s.color.x; i += 1
            instanceData[i] = s.color.y; i += 1
            instanceData[i] = s.color.z; i += 1
        }
    }
}
