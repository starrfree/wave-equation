//
//  ImageLoader.swift
//  Wave Equation
//
//  Created by Eliott Morgensztern on 22/05/2022.
//

import Foundation
import MetalKit

class ImageLoader {
    static func getMTLTexture(from cgimg: CGImage, device: MTLDevice) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            let texture = try textureLoader.newTexture(cgImage: cgimg, options: [.SRGB : (false as NSNumber)])
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: cgimg.width, height: cgimg.height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead]
            return texture
        } catch {
            print("Couldn't convert CGImage to MTLtexture:", error)
        }
        return nil
    }
    
    #if os(macOS)
    static func cgimage(named name: String, subdirectory: String) -> CGImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory) {
            if let image = NSImage(contentsOf: url) {
                var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                let imageRef = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
                return imageRef
            } else {
                print("Could not get NSImage from URL.")
            }
        } else {
            print("Could not get URL.")
        }
        return nil
    }
    
    static func cgimage(at url: URL) -> CGImage? {
        if let image = NSImage(contentsOf: url) {
            var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            let imageRef = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
            return imageRef
        } else {
            print("Could not get NSImage from URL.")
        }
        return nil
    }
    #else
    static func cgimage(named name: String, subdirectory: String) -> CGImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory) {
            if let image = UIImage(contentsOfFile: url.path) {
                return image.cgImage
            } else {
                print("Could not get NSImage from URL.")
            }
        } else {
            print("Could not get URL.")
        }
        return nil
    }
    #endif
}
