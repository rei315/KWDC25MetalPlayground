//
// AlphaMetal4VideoView.swift
// HEVCPlayer
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

import MetalKit
import AVFoundation
import Shared

public final class AlphaMetal4VideoView: MTKView {
  private var commandQueue: MTL4CommandQueue!
  private var commandBuffer: MTL4CommandBuffer!
  private var pipelineState: MTLRenderPipelineState!
  private var textureCache: CVMetalTextureCache?
  private var samplerState: MTLSamplerState!
  private var vertexArgumentTable: MTL4ArgumentTable!
  private var fragmentArgumentTable: MTL4ArgumentTable!
  private var commandAllocator: MTL4CommandAllocator!
  private var residencySet: MTLResidencySet!
  
  private var yTexture: MTLTexture?
  private var cbcrTexture: MTLTexture?
  private var alphaTexture: MTLTexture?
  
  private var vertexUniformBuffer: MTLBuffer?
  private var videoContentMode: VideoContentMode = .scaleAspectFill
  
  public init(device: MTLDevice) {
    super.init(frame: .zero, device: device)
    initialize(device: device)
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func initialize(device: MTLDevice) {
    self.framebufferOnly = false
    self.isPaused = true
    self.enableSetNeedsDisplay = true
#if os(macOS)
    self.layer?.isOpaque = false
    self.canDrawConcurrently = true
#elseif os(iOS)
    self.layer.isOpaque = false
    self.layer.drawsAsynchronously = true
#endif
    self.clearColor = MTLClearColorMake(0, 0, 0, 0)
    self.preferredFramesPerSecond = 60
    self.delegate = self
    
    MakeLibraryAndPipelineState: do {
      guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
        fatalError("Failed to create library")
      }
      
      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_function")
      pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_function")
      pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
      pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
      pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
      pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
      pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
      pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
      pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
      guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
        fatalError("Failed to create pipelineState")
      }
      self.pipelineState = pipelineState
    }
    
    MakeCommandQueue: do {
      guard let commandQueue = device.makeMTL4CommandQueue() else {
        fatalError("Failed to create commandQueue")
      }
      self.commandQueue = commandQueue
    }
    
    MakeCommandBuffer: do {
      guard let commandBuffer = device.makeCommandBuffer() else {
        fatalError("Failed to create commandBuffer")
      }
      self.commandBuffer = commandBuffer
    }
    
    MakeResidencySet: do {
      let residencySetDesc = MTLResidencySetDescriptor()
      guard let residencySet = try? device.makeResidencySet(descriptor: residencySetDesc) else {
        fatalError("Failed to init")
      }
      self.residencySet = residencySet
      commandQueue.addResidencySet(residencySet)
    }
    
    MakeArgumentTable: do {
      let fragmentArgumentTableDesc = MTL4ArgumentTableDescriptor()
      fragmentArgumentTableDesc.maxTextureBindCount = 3
      fragmentArgumentTableDesc.maxSamplerStateBindCount = 1
      let vertexArgumentTableDesc = MTL4ArgumentTableDescriptor()
      vertexArgumentTableDesc.maxBufferBindCount = 1
      guard let fragmentArgumentTable = try? device.makeArgumentTable(descriptor: fragmentArgumentTableDesc),
            let vertexArgumentTable = try? device.makeArgumentTable(descriptor: vertexArgumentTableDesc) else {
        fatalError("Failed to create argumentTables")
      }
      self.fragmentArgumentTable = fragmentArgumentTable
      self.vertexArgumentTable = vertexArgumentTable
    }
    
    MakeAllocators: do {
      guard let commandAllocator = device.makeCommandAllocator() else {
        fatalError("Failed to create commandAllocator")
      }
      self.commandAllocator = commandAllocator
    }
    
    Resources: do {
      let samplerDescriptor = MTLSamplerDescriptor()
      samplerDescriptor.minFilter = .linear
      samplerDescriptor.magFilter = .linear
      samplerDescriptor.sAddressMode = .clampToEdge
      samplerDescriptor.tAddressMode = .clampToEdge
      guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
        fatalError("Failed to create samplerState")
      }
      self.samplerState = samplerState
      
      CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
  }
}

// MARK: - public
extension AlphaMetal4VideoView {
  @MainActor
  func updateTextures(pixelBuffer: CVPixelBuffer) {
    func makeTexture(plane: Int, format: MTLPixelFormat) -> MTLTexture? {
      guard let textureCache = textureCache else { return nil }
      var cvTexture: CVMetalTexture?
      let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane)
      let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
      CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, format, width, height, plane, &cvTexture)
      guard let cvTexture else {
        return nil
      }
      
      return CVMetalTextureGetTexture(cvTexture)
    }
    guard let yTexture = makeTexture(plane: 0, format: .r8Unorm),
          let cbcrTexture = makeTexture(plane: 1, format: .rg8Unorm),
          let alphaTexture = makeTexture(plane: 2, format: .r8Unorm) else {
      return
    }
    self.yTexture = yTexture
    self.cbcrTexture = cbcrTexture
    self.alphaTexture = alphaTexture
    residencySet.removeAllAllocations()
    residencySet.addAllocation(yTexture)
    residencySet.addAllocation(cbcrTexture)
    residencySet.addAllocation(alphaTexture)
    residencySet.commit()
    
    if vertexUniformBuffer == nil {
      let width = yTexture.width
      let height = yTexture.height
      updateVertexUniform(textureWidth: width, textureHeight: height)
    }
    
#if os(macOS)
    setNeedsDisplay(bounds)
#elseif os(iOS)
    setNeedsDisplay()
#endif
  }
  
  func reset() {
    yTexture = nil
    cbcrTexture = nil
    alphaTexture = nil
    vertexUniformBuffer = nil
    residencySet.removeAllAllocations()
    residencySet.commit()
    if let cache = textureCache {
      CVMetalTextureCacheFlush(cache, 0)
    }
  }
  
  func finish() {
    reset()
#if os(macOS)
    setNeedsDisplay(bounds)
#elseif os(iOS)
    setNeedsDisplay()
#endif
  }
}

// MARK: - private
extension AlphaMetal4VideoView {
  private func render() {
    guard let pipelineState,
          let currentDrawable,
          let currentMTL4RenderPassDescriptor else {
      return
    }
    
    commandAllocator.reset()
    commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    
    guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentMTL4RenderPassDescriptor) else {
      return
    }
    
    if let yTexture,
       let cbcrTexture,
       let alphaTexture {
      renderCommandEncoder.setRenderPipelineState(pipelineState)
      renderCommandEncoder.setArgumentTable(fragmentArgumentTable, stages: .fragment)
      if let vertexUniformBuffer {
        renderCommandEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
        vertexArgumentTable.setAddress(vertexUniformBuffer.gpuAddress, index: 0)
      }
      fragmentArgumentTable.setTexture(yTexture.gpuResourceID, index: 0)
      fragmentArgumentTable.setTexture(cbcrTexture.gpuResourceID, index: 1)
      fragmentArgumentTable.setTexture(alphaTexture.gpuResourceID, index: 2)
      fragmentArgumentTable.setSamplerState(samplerState.gpuResourceID, index: 0)
      renderCommandEncoder.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    renderCommandEncoder.endEncoding()
    
    commandBuffer.endCommandBuffer()
    commandQueue.commit([commandBuffer])
    commandQueue.signalDrawable(currentDrawable)
    currentDrawable.present()
  }
  
  private func updateVertexUniform(textureWidth: Int, textureHeight: Int) {
    guard let drawableSize = self.currentDrawable?.layer.drawableSize else {
      return
    }
    
    let viewWidth = drawableSize.width
    let viewHeight = drawableSize.height
    let videoWidth = Float(textureWidth)
    let videoHeight = Float(textureHeight)
    
    let viewAspect = Float(viewWidth / viewHeight)
    let videoAspect = videoWidth / videoHeight
    
    var scaleX: Float = 1.0
    var scaleY: Float = 1.0
    
    switch videoContentMode {
    case .scaleAspectFit:
      if videoAspect > viewAspect {
        scaleY = viewAspect / videoAspect
      } else {
        scaleX = videoAspect / viewAspect
      }
    case .scaleAspectFill:
      if videoAspect > viewAspect {
        scaleX = videoAspect / viewAspect
      } else {
        scaleY = viewAspect / videoAspect
      }
    }
    
    var scaleVector = SIMD2<Float>(scaleX, scaleY)
    vertexUniformBuffer = device?.makeBuffer(
      bytes: &scaleVector,
      length: MemoryLayout<SIMD2<Float>>.size,
      options: [.storageModeShared]
    )
  }
}

extension AlphaMetal4VideoView: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    guard let yTexture else {
      return
    }
    updateVertexUniform(textureWidth: yTexture.width, textureHeight: yTexture.height)
  }
  
  public func draw(in view: MTKView) {
    render()
  }
}
