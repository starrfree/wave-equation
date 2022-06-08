//
//  MetalView.swift
//  MetalShader
//
//  Created by Eliott Morgensztern on 24/07/2021.
//

import Foundation
import SwiftUI
import Metal
import MetalKit

#if canImport(UIKit)
typealias ViewController = UIViewController
typealias ViewControllerRepresentable = UIViewControllerRepresentable
typealias ViewControllerRepresentableContext = UIViewControllerRepresentableContext
#else
typealias ViewController = NSViewController
typealias ViewControllerRepresentable = NSViewControllerRepresentable
typealias ViewControllerRepresentableContext = NSViewControllerRepresentableContext
#endif

final class MetalViewController: ViewController, MTKViewDelegate {
    var metalComputer = MetalComputer()
    var metalView: MTKView = MTKView()
    var parameters = Parameters()
    
    var saveImages = false /// toggle to save images
    var imageFolder: URL?
    var simulationSteps = 0
    var imageSaved = 0
    
    #if canImport(UIKit)
    override func viewDidLoad() {
        initialize()
    }
    #else
    override func loadView() {
        view = NSView(frame: NSMakeRect(0, 0, 400, 300))
        initialize()
    }
    #endif
    
    func initialize() {
        setupSubviews()
        setupMetalView()
        initBuffers()
    }

    func setupMetalView() {
        metalView.device = metalComputer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.delegate = self
        metalView.framebufferOnly = false
    }
    
    /// initialize all buffers before computation
    func initBuffers() {
        guard let texture = metalView.currentDrawable?.texture else { return }
        let pixelSize: Int = 1
        /// "boundary image": the alpha component gives the speed of the wave. Alpha = 0 => wall
        let image: CGImage? = ImageLoader.cgimage(named: "lens 2", subdirectory: "Shapes")
        /// gradient image: dictates the color of the wave given it's value. value = -1 => top; value = 1 => bottom of the gradient image
        let gradient: CGImage? = ImageLoader.cgimage(named: "bluewhitered sat", subdirectory: "Gradient")
        /// init buffers for Metal
        metalComputer.initalizeBuffers(width: texture.width / pixelSize, height: texture.height / pixelSize, textureWidth: texture.width, textureHeight: texture.height, image: image, gradient: gradient)
        #if os(macOS)
        if saveImages {
            /// wait for folder choice
            metalView.isPaused = true
            DispatchQueue.main.async {
                /// prompt folder
                self.promptImageFolder { [self] in
                    simulationSteps = 0
                    metalView.isPaused = false
                }
            }
        }
        #endif
    }
    
    /// make MTKView fill view
    func setupSubviews() {
        metalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView)
        NSLayoutConstraint.activate([
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }
    
    /// called when the view resizes
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        initBuffers()
    }
    
    /// called every frame
    func draw(in view: MTKView) {
        guard let commandBuffer = metalComputer.commandQueue?.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable
        else {
            print("draw error")
            return
        }
        
        /// make sure the view is the same width as the texture from metalComputer
        if currentDrawable.texture.width != metalComputer.textureWidth {
            initBuffers()
        }
        
        /// make sure the view is the same height as the texture from metalComputer
        if currentDrawable.texture.height != metalComputer.textureHeight {
            initBuffers()
        }
        
        /// Compute 9 iterations
        metalComputer.compute(to: currentDrawable.texture, parameters: parameters, iterations: 9)
        
        #if os(macOS)
        if let url = imageFolder, saveImages {
            /// save every x steps
            if simulationSteps % 1 == 0 {
                saveTextureToFile(texture: currentDrawable.texture, url: url.appendingPathComponent(String(imageSaved) + ".png"))
                print("Saved:", imageSaved)
                imageSaved += 1
            }
            /// exit after x images saved
            if imageSaved > 3000 {
                exit(2002)
            }
        }
        simulationSteps += 1
        #endif
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
    }
    
    #if os(macOS)
    func promptImageFolder(completion: @escaping () -> ()) {
        let panel = NSOpenPanel()
        panel.message = "Select folder to save the images"
        panel.prompt = "Select"
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if let window = NSApplication.shared.windows.first {
            panel.beginSheetModal(for: window) { result in
                if result == .OK {
                    self.imageFolder = panel.url
                    completion()
                }
            }
        }
    }

    func saveTextureToFile(texture: MTLTexture, url: URL) {
        let kciOptions = [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB()]
        let ciImage = CIImage(mtlTexture: texture, options: kciOptions)!
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = NSImage(cgImage: cgImage!, size: NSSize(width: texture.width, height: texture.height))
        let data = image.tiffRepresentation
        let bitmapRep = NSBitmapImageRep(data: data!)
        let pngData = bitmapRep?.representation(using: .png, properties: [:])
        if let pngData = pngData {
            do {
                try pngData.write(to: url)
            } catch {
                print("Failed write pngData:", error)
            }
        } else {
            print("No PNG data.")
        }
    }
    #endif
}

extension MetalViewController : ViewControllerRepresentable {
    #if canImport(UIKit)
    public func makeUIViewController(context: ViewControllerRepresentableContext<MetalViewController>) -> MetalViewController {
        return self
    }
    
    public func updateUIViewController(_ uiViewController: MetalViewController, context: ViewControllerRepresentableContext<MetalViewController>) {
    }
    #else
    public func makeNSViewController(context: ViewControllerRepresentableContext<MetalViewController>) -> MetalViewController {
        return self
    }
    
    public func updateNSViewController(_ nsViewController: MetalViewController, context: ViewControllerRepresentableContext<MetalViewController>) {
    }
    #endif
}
