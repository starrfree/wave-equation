//
//  MetalController.swift
//  MetalShader
//
//  Created by Eliott Morgensztern on 24/07/2021.
//

import Foundation
import MetalKit
import simd

struct Tile {
    var value: Float = 0
    var prevValue: Float = 0
}

struct Parameters {
    var width: Int32 = 0
    var height: Int32 = 0
    var textureWidth: Int32 = 0
    var textureHeight: Int32 = 0
    var step: Int32 = 0
}

class MetalComputer {
    let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    let commandQueue: MTLCommandQueue?
    let ciContext: CIContext
    private var computeFunction: MTLFunction?
    private var computePipelineState: MTLComputePipelineState!
    private var copyFunction: MTLFunction?
    private var copyPipelineState: MTLComputePipelineState!
    private var maxThreadsPerThreadgroup: Int = 0
    
    var tileMapIn: MTLBuffer? = nil
    var tileMapOut: MTLBuffer? = nil
    var energyMap: MTLBuffer? = nil
    var boundaryTexture: MTLTexture? = nil
    var gradientTexture: MTLTexture? = nil
    var tileWidth: Int = 0
    var tileHeight: Int = 0
    var textureWidth: Int = 0
    var textureHeight: Int = 0
    var lastTime = Date()
    var step: Int = 0
    
    init() {
        if let _ = device {
            print("Metal device found")
        } else {
            print("No Metal device")
        }
        commandQueue = device?.makeCommandQueue()
        ciContext = CIContext(mtlDevice: device!)
        computeFunction = getFunction(name: "compute_kernel")
        copyFunction = getFunction(name: "copy_to_texture")
        do {
            computePipelineState = try device?.makeComputePipelineState(function: computeFunction!)
            copyPipelineState = try device?.makeComputePipelineState(function: copyFunction!)
        } catch {
            print(error)
        }
        maxThreadsPerThreadgroup = Int(sqrt(Double(computePipelineState.maxTotalThreadsPerThreadgroup)))
    }
    
    func initalizeBuffers(width: Int, height: Int, textureWidth: Int, textureHeight: Int, image: CGImage? = nil, gradient: CGImage? = nil) {
        tileWidth = width
        tileHeight = height
        self.textureWidth = textureWidth
        self.textureHeight = textureHeight
        let tileMapInArray = initializeTilemap(width: width, height: height)
        let emptyTileMapArray = Array<Tile>(repeating: Tile(), count: width * height)
        tileMapIn = device?.makeBuffer(bytes: tileMapInArray, length: MemoryLayout<Tile>.stride * width * height, options: .storageModeShared)
        tileMapOut = device?.makeBuffer(bytes: emptyTileMapArray, length: MemoryLayout<Tile>.stride * width * height, options: .storageModeShared)
        energyMap = device?.makeBuffer(bytes: emptyTileMapArray, length: MemoryLayout<Tile>.stride * width * height, options: .storageModeShared)
        if let image = image {
            boundaryTexture = ImageLoader.getMTLTexture(from: image, device: device!)
        }
        if let gradient = gradient {
            gradientTexture = ImageLoader.getMTLTexture(from: gradient, device: device!)
        }
        step = 0
    }
    
    /// toggle comments to initialize the wave with a pattern
    func initializeTilemap(width: Int, height: Int) -> Array<Tile> {
        var tilemap = Array<Tile>(repeating: Tile(), count: width * height)
        let w = Float(width)
        for y in 0..<height {
            for x in 0..<width {
                /// Gaussian wave
//                let dx = Float(x - width / 2)
//                let dy = Float(y - height / 2)
//                let v: Float = 10 * exp(-(dx*dx + dy*dy) / w * 6)
//                let index = x + y * width
//                tilemap[index].value = v
//                tilemap[index].prevValue = v
                
                /// Sine wave
//                let xf = Float(x)
//                var v1 = 1.5 * sin(xf * 300 / w)
//                if (x > width / 4) { //|| x < width / 4 - 40
//                    v1 = 0
//                }
//                let index = x + y * width
//                tilemap[index].value = v1
//                tilemap[index].prevValue = v1
            }
        }
        return tilemap
    }
    
    func compute(to texture: MTLTexture, parameters: Parameters, iterations: Int = 1) {
        var params = parameters
        params.textureWidth = Int32(textureWidth)
        params.textureHeight = Int32(textureHeight)
        params.width = Int32(tileWidth)
        params.height = Int32(tileHeight)
        for _ in 0..<iterations {
            params.step = Int32(step)
            
            let commandBuffer = commandQueue?.makeCommandBuffer()
            let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
            commandEncoder?.setComputePipelineState(computePipelineState)
            
            let threadsPerGrid = MTLSize(width: tileWidth, height: tileHeight, depth: 1)
            let maxWidth = Int(sqrt(Double(computePipelineState.maxTotalThreadsPerThreadgroup)))
            let threadsPerThreadgroup = MTLSize(width: maxWidth, height: maxWidth, depth: 1)
            /// PROCESS GRID
            commandEncoder?.setComputePipelineState(computePipelineState)
            commandEncoder?.setBuffer(tileMapIn, offset: 0, index: 0)
            commandEncoder?.setBuffer(tileMapOut, offset: 0, index: 1)
            commandEncoder?.setBuffer(energyMap, offset: 0, index: 2)
            commandEncoder?.setTexture(boundaryTexture, index: 0)
            commandEncoder?.setBytes(&params, length: MemoryLayout<Parameters>.stride, index: 3)
            commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            
            /// COPY TO TEXTURE
            commandEncoder?.setComputePipelineState(copyPipelineState)
            commandEncoder?.setBuffer(tileMapIn, offset: 0, index: 0)
            commandEncoder?.setBuffer(tileMapOut, offset: 0, index: 1)
            commandEncoder?.setBuffer(energyMap, offset: 0, index: 2)
            commandEncoder?.setBytes(&params, length: MemoryLayout<Parameters>.stride, index: 3)
            commandEncoder?.setTexture(texture, index: 0)
            commandEncoder?.setTexture(boundaryTexture, index: 1)
            commandEncoder?.setTexture(gradientTexture, index: 2)
            commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            
            commandEncoder?.endEncoding()
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
            
            step += 1
        }
    }
    
    func getFunction(name: String) -> MTLFunction? {
        let gpuFunctionLibrary = device?.makeDefaultLibrary()
        return gpuFunctionLibrary?.makeFunction(name: name)
    }
    
    func getEmptyMTLTexture(width: Int, height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.rgba32Float,
            width: width,
            height: height,
            mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        return device?.makeTexture(descriptor: textureDescriptor)
    }
}
