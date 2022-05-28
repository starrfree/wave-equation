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
    
    var saveImages = true
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
        #if os(macOS)
        if saveImages {
            DispatchQueue.main.async {
                self.promptImageFolder(prompt: "Select folder to save the images") { [self] path in
                    self.imageFolder = path
                    simulationSteps = 0
                    drawSequence()
                }
            }
        } else {
            drawSequence()
        }
        #endif
    }

    func setupMetalView() {
        metalView.device = metalComputer.device
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.delegate = self
        metalView.framebufferOnly = false
        metalView.isPaused = true
    }
    
    func initBuffers(imageURL: URL? = nil) {
        guard let texture = metalView.currentDrawable?.texture else { return }
        let pixelSize: Int = 2
        let image: CGImage?
        if let url = imageURL {
            image = ImageLoader.cgimage(at: url)
        } else {
            image = ImageLoader.cgimage(named: "lens 2", subdirectory: "Shapes")
        }
        let gradient: CGImage? = ImageLoader.cgimage(named: "plasma", subdirectory: "Gradient")
        metalComputer.initalizeBuffers(width: texture.width / pixelSize, height: texture.height / pixelSize, textureWidth: texture.width, textureHeight: texture.height, image: image, gradient: gradient)
    }

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

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        initBuffers()
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = metalComputer.commandQueue?.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable
        else {
            print("draw error")
            return
        }
        if currentDrawable.texture.width != metalComputer.textureWidth {
            initBuffers()
            return
        }
        
        if currentDrawable.texture.height != metalComputer.textureHeight {
            initBuffers()
            return
        }
        
        metalComputer.compute(to: currentDrawable.texture, parameters: parameters, iterations: 2650)
        
        #if os(macOS)
        if let url = imageFolder, saveImages {
            if simulationSteps % 1 == 0 {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "ss:mm:hh"
                saveTextureToFile(texture: currentDrawable.texture, url: url.appendingPathComponent(String(imageSaved) + ".png"))
                print("Saved:", imageSaved)
                imageSaved += 1
            }
            if imageSaved > 30000 {
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
    func drawSequence() {
        DispatchQueue.main.async {
            self.promptImageFolder(prompt: "Select sequence folder") { url in
                if let url = url {
                    let fileNames = try! FileManager.default.contentsOfDirectory(atPath: url.path)
                    let fileNamesFiltered = fileNames.filter({ str in
                        return Int(str.replacingOccurrences(of: ".png", with: "")) != nil
                    })
                    let fileNamesSorted = fileNamesFiltered.sorted(by: { a, b in
                        return Int(a.replacingOccurrences(of: ".png", with: ""))! < Int(b.replacingOccurrences(of: ".png", with: ""))!
                    })
                    for i in 0..<fileNamesSorted.count {
                        let fileName = fileNamesSorted[i]
                        DispatchQueue.main.async { [self] in
                            initBuffers(imageURL: url.appendingPathComponent(fileName))
                            metalView.draw()
                        }
                    }
                }
            }
        }
    }
    
    func promptImageFolder(prompt: String, completion: @escaping (URL?) -> ()) {
        let panel = NSOpenPanel()
        panel.message = prompt
        panel.prompt = "Select"
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if let window = NSApplication.shared.windows.first {
            panel.beginSheetModal(for: window) { result in
                if result == .OK {
                    completion(panel.url)
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
