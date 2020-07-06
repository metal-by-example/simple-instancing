
import Cocoa
import MetalKit

class ViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = MTLCreateSystemDefaultDevice()!
        
        mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.sampleCount = 4
        
        mtkView.autoresizingMask = [.width, .height]
        view.addSubview(mtkView)
        
        renderer = Renderer(view: mtkView)
    }
}

