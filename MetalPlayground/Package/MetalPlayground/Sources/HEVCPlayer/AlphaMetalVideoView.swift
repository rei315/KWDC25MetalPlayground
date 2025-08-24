//
// AlphaMetalVideoView.swift
// HEVCPlayer
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

import MetalKit
import AVFoundation
import Shared

public final class AlphaMetalVideoView: MTKView {
  private var commandQueue: MTLCommandQueue
  private var pipelineState: MTLRenderPipelineState?
  private var textureCache: CVMetalTextureCache?
  private var samplerState: MTLSamplerState
  
  private var yTexture: MTLTexture?
  private var cbcrTexture: MTLTexture?
  private var alphaTexture: MTLTexture?
  
  private var vertexUniformBuffer: MTLBuffer?
  private var videoContentMode: VideoContentMode = .scaleAspectFill
  
  public init(device: MTLDevice) {
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    guard let commandQueue = device.makeCommandQueue(),
          let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
      fatalError("Failed to init")
    }
    self.commandQueue = commandQueue
    self.samplerState = samplerState
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
    
    let library = try! device.makeDefaultLibrary(bundle: .module)
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
    
    pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
  }
}

// MARK: - public
extension AlphaMetalVideoView {
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
    yTexture = makeTexture(plane: 0, format: .r8Unorm)
    cbcrTexture = makeTexture(plane: 1, format: .rg8Unorm)
    alphaTexture = makeTexture(plane: 2, format: .r8Unorm)
    if vertexUniformBuffer == nil,
       let width = yTexture?.width,
       let height = yTexture?.height {
      updateVertexUniform(textureWidth: width, textureHeight: height)
    }
    setNeedsDisplay(bounds)
  }
  
  func reset() {
    yTexture = nil
    cbcrTexture = nil
    alphaTexture = nil
    vertexUniformBuffer = nil
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

extension AlphaMetalVideoView {
  private func render() {
    guard let pipelineState,
          let currentDrawable,
          let currentRenderPassDescriptor else {
      return
    }
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
    
    if let yTexture,
       let cbcrTexture,
       let alphaTexture {
      renderCommandEncoder.setRenderPipelineState(pipelineState)
      if let vertexUniformBuffer {
        renderCommandEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 0)
      }
      renderCommandEncoder.setFragmentTexture(yTexture, index: 0)
      renderCommandEncoder.setFragmentTexture(cbcrTexture, index: 1)
      renderCommandEncoder.setFragmentTexture(alphaTexture, index: 2)
      renderCommandEncoder.setFragmentSamplerState(samplerState, index: 0)
      renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    renderCommandEncoder.endEncoding()
    commandBuffer.present(currentDrawable)
    commandBuffer.commit()
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

extension AlphaMetalVideoView: MTKViewDelegate {
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
