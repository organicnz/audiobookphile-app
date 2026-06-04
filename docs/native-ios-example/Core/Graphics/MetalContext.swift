//
//  MetalContext.swift
//  AudiobookphileClient
//
//  Metal framework setup for GPU-accelerated rendering
//

import Metal
import MetalKit
import UIKit
import SwiftUI

/// Metal rendering context for GPU-accelerated effects
@MainActor
class MetalContext: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var deviceName: String = "Unknown"
    
    // MARK: - Metal Properties
    private(set) var device: MTLDevice?
    private(set) var commandQueue: MTLCommandQueue?
    private(set) var library: MTLLibrary?
    private var textureCache: CVMetalTextureCache?
    
    // MARK: - Singleton
    static let shared = MetalContext()
    
    private init() {
        setup()
    }
    
    // MARK: - Setup
    private func setup() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal is not supported on this device")
            return
        }
        
        self.device = device
        self.deviceName = device.name
        self.commandQueue = device.makeCommandQueue()
        
        // Create default library (contains built-in shaders)
        self.library = device.makeDefaultLibrary()
        
        // Create texture cache for efficient image processing
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        self.textureCache = cache
        
        isAvailable = true
        print("✅ Metal initialized: \(deviceName)")
        print("   Max threads per threadgroup: \(device.maxThreadsPerThreadgroup)")
        print("   Supports family Apple7: \(device.supportsFamily(.apple7))")
    }
    
    // MARK: - Texture Creation
    
    /// Create a texture from UIImage
    func createTexture(from image: UIImage) -> MTLTexture? {
        guard let device = device,
              let cgImage = image.cgImage else { return nil }
        
        let textureLoader = MTKTextureLoader(device: device)
        
        do {
            let texture = try textureLoader.newTexture(
                cgImage: cgImage,
                options: [
                    .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                    .textureStorageMode: MTLStorageMode.private.rawValue
                ]
            )
            return texture
        } catch {
            print("❌ Failed to create texture: \(error)")
            return nil
        }
    }
    
    /// Create an empty texture with specified dimensions
    func createTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .bgra8Unorm
    ) -> MTLTexture? {
        guard let device = device else { return nil }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    // MARK: - Command Buffer
    
    /// Create a command buffer for encoding GPU commands
    func makeCommandBuffer() -> MTLCommandBuffer? {
        return commandQueue?.makeCommandBuffer()
    }
    
    // MARK: - Compute Pipeline
    
    /// Create compute pipeline state for a shader function
    func makeComputePipelineState(
        functionName: String
    ) -> MTLComputePipelineState? {
        guard let device = device,
              let library = library,
              let function = library.makeFunction(name: functionName) else {
            print("❌ Failed to create function: \(functionName)")
            return nil
        }
        
        do {
            let pipelineState = try device.makeComputePipelineState(function: function)
            print("✅ Created compute pipeline: \(functionName)")
            return pipelineState
        } catch {
            print("❌ Failed to create pipeline state: \(error)")
            return nil
        }
    }
    
    // MARK: - Performance Info
    
    /// Get Metal device capabilities
    func getDeviceCapabilities() -> String {
        guard let device = device else { return "Metal not available" }
        
        var info = "Metal Device Info:\n"
        info += "Name: \(device.name)\n"
        info += "Max threads per group: \(device.maxThreadsPerThreadgroup.width)x\(device.maxThreadsPerThreadgroup.height)\n"
        info += "Max buffer length: \(device.maxBufferLength / 1_000_000)MB\n"
        info += "Recommended max working set: \(device.recommendedMaxWorkingSetSize / 1_000_000)MB\n"
        
        if device.supportsFamily(.apple7) {
            info += "Supports: Apple7 (iPhone 13+)\n"
        } else if device.supportsFamily(.apple6) {
            info += "Supports: Apple6 (iPhone 11+)\n"
        }
        
        return info
    }
}

// MARK: - Metal Renderer Protocol

@MainActor
protocol MetalRenderable {
    /// Render using Metal
    func render(in context: MetalContext, commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

// MARK: - Blur Renderer

/// GPU-accelerated blur using Metal
@MainActor
class MetalBlurRenderer: MetalRenderable {
    private var pipelineState: MTLComputePipelineState?
    private let context: MetalContext
    
    @MainActor
    init(context: MetalContext) {
        self.context = context
        // In a real implementation, you'd create the blur compute pipeline here
        // self.pipelineState = context.makeComputePipelineState(functionName: "gaussian_blur")
    }
    
    func render(
        in context: MetalContext,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        // Metal blur implementation would go here
        // This is a placeholder for the actual Metal shader execution
        return nil
    }
    
    /// Apply gaussian blur to texture
    func blur(
        texture: MTLTexture,
        radius: Float,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        guard let pipelineState = pipelineState,
              let device = context.device else { return nil }
        
        // Create output texture
        let outputTexture = context.createTexture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat
        )
        
        guard let output = outputTexture else { return nil }
        
        // Create compute command encoder
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(output, index: 1)
        
        // Set blur radius parameter
        var blurRadius = radius
        encoder.setBytes(&blurRadius, length: MemoryLayout<Float>.size, index: 0)
        
        // Calculate thread groups
        let threadgroupSize = MTLSize(
            width: 16,
            height: 16,
            depth: 1
        )
        let threadgroups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        
        return output
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Enable Metal rendering for this view
    func metalAccelerated() -> some View {
        self.drawingGroup() // Forces Metal rendering
    }
}

// MARK: - Preview
#Preview("Metal Context Info") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            if MetalContext.shared.isAvailable {
                Text("Metal Available ✅")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        MetalInfoRow(
                            label: "Device",
                            value: MetalContext.shared.deviceName
                        )
                        
                        if let device = MetalContext.shared.device {
                            MetalInfoRow(
                                label: "Max Threads",
                                value: "\(device.maxThreadsPerThreadgroup.width)×\(device.maxThreadsPerThreadgroup.height)"
                            )
                            
                            MetalInfoRow(
                                label: "Family",
                                value: device.supportsFamily(.apple7) ? "Apple7+" : "Apple6+"
                            )
                        }
                    }
                }
                
                Text(MetalContext.shared.getDeviceCapabilities())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .glassCard()
                
            } else {
                Text("Metal Not Available ❌")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
    .background {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct MetalInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
