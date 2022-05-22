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
    
    func initBuffers() {
        guard let texture = metalView.currentDrawable?.texture else { return }
        let pixelSize: Int = 1
        metalComputer.initalizeBuffers(width: texture.width / pixelSize, height: texture.height / pixelSize, textureWidth: texture.width, textureHeight: texture.height, image: ImageLoader.cgimage(named: "ellipse"))
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
        }
        
        if currentDrawable.texture.height != metalComputer.textureHeight {
            initBuffers()
        }
        
        metalComputer.compute(to: currentDrawable.texture, parameters: parameters)
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
    }
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
