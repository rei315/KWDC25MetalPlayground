//
// AlphaMetal4PerformanceVideoView.swift
// HEVCPlayer
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

import MetalKit
import AVFoundation
import Shared

@MainActor
protocol AlphaMetal4PerformanceVideoViewDelegate: AnyObject {
  func drawableSizeWillChange(_ size: CGSize)
}

public final class AlphaMetal4PerformanceVideoView: MTKView {
  weak var viewDelegate: (any AlphaMetal4PerformanceVideoViewDelegate)?
  
  private var commandQueue: MTL4CommandQueue!
  private var commandBuffer: MTL4CommandBuffer!
  private var pipelineState: MTLRenderPipelineState!
  private var samplerState: MTLSamplerState!
  private var renderPassDescriptor: MTL4RenderPassDescriptor!
  private var fragmentArgumentTable: MTL4ArgumentTable!
  private var vertexArgumentTable: MTL4ArgumentTable!
  private var commandAllocators: [MTL4CommandAllocator] = []
  
  private var sharedEvent: MTLSharedEvent!
  private var frameNumber: UInt64 = 0
  
  private let textureManager: TextureManager
  
  private var vertexUniformBuffer: MTLBuffer!
  private var videoContentMode: VideoContentMode = .scaleAspectFill
  private let kMaxFramesInFlight = 3
  
  public init(device: MTLDevice) {
    self.textureManager = .init(device: device, kMaxFramesInFlight: kMaxFramesInFlight)
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
      self.commandQueue.addResidencySet(textureManager.residencySet)
    }
    
    MakeCommandBuffer: do {
      guard let commandBuffer = device.makeCommandBuffer() else {
        fatalError("Failed to create commandBuffer")
      }
      self.commandBuffer = commandBuffer
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
      self.commandAllocators = (0..<kMaxFramesInFlight).compactMap { _ in
        device.makeCommandAllocator()
      }
    }
    
    MakeSharedEvent: do {
      guard let sharedEvent = device.makeSharedEvent() else {
        fatalError("Failed to create Others")
      }
      
      self.sharedEvent = sharedEvent
      self.sharedEvent.signaledValue = frameNumber
    }
    
    MakeRenderPassDescriptor: do {
      self.renderPassDescriptor = MTL4RenderPassDescriptor()
      self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
      self.renderPassDescriptor.colorAttachments[0].storeAction = .store
      self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    }
    
    Resources: do {
      var scaleVector = SIMD2<Float>(1.0, 1.0)
      guard let vertexUniformBuffer = device.makeBuffer(
        bytes: &scaleVector,
        length: MemoryLayout<SIMD2<Float>>.size,
        options: [.storageModeShared]
      ) else {
        fatalError("Failed to create vertex buffer")
      }
      self.vertexUniformBuffer = vertexUniformBuffer
      
      let samplerDescriptor = MTLSamplerDescriptor()
      samplerDescriptor.minFilter = .linear
      samplerDescriptor.magFilter = .linear
      samplerDescriptor.sAddressMode = .clampToEdge
      samplerDescriptor.tAddressMode = .clampToEdge
      guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
        fatalError("Failed to create samplerState")
      }
      self.samplerState = samplerState
    }
  }
}

// MARK: - public
extension AlphaMetal4PerformanceVideoView {
  func flush() {
    sharedEvent.notify(.init(dispatchQueue: .global(qos: .userInitiated)), atValue: sharedEvent.signaledValue) { [weak self] event, value in
      guard let self else {
        return
      }
      Task { @MainActor in
        frameNumber = .zero
        sharedEvent.signaledValue = .zero
        textureManager.flush()
      }
    }
  }
  
  func reset() {
    sharedEvent.notify(.init(dispatchQueue: .global(qos: .userInitiated)), atValue: sharedEvent.signaledValue) { [weak self] event, value in
      guard let self else {
        return
      }
      Task { @MainActor in
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        event.signaledValue = .zero
        frameNumber = .zero
        textureManager.reset()
      }
    }
  }
  
  func finish() {
    sharedEvent.notify(.init(dispatchQueue: .global(qos: .userInitiated)), atValue: sharedEvent.signaledValue) { [weak self] event, value in
      guard let self else {
        return
      }
      Task { @MainActor in
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        textureManager.reset()
#if os(macOS)
    setNeedsDisplay(bounds)
#elseif os(iOS)
    setNeedsDisplay()
#endif
        event.signaledValue = .zero
        frameNumber = .zero
      }
    }
  }
  
  func updateTextures(pixelBuffer: CVPixelBuffer) {
    textureManager.update(frame: frameNumber, pixelBuffer: pixelBuffer)
#if os(macOS)
    setNeedsDisplay(bounds)
#elseif os(iOS)
    setNeedsDisplay()
#endif
  }
}

// MARK: - private
extension AlphaMetal4PerformanceVideoView {
  private func render() {
    guard let pipelineState else {
      return
    }
    
    frameNumber += 1
    if frameNumber >= kMaxFramesInFlight {
      let waitValue = frameNumber - UInt64(kMaxFramesInFlight)
      _ = sharedEvent.wait(untilSignaledValue: waitValue, timeoutMS: 8)
    }
    
    let textureIndex = Int((frameNumber - 1) % UInt64(kMaxFramesInFlight))
    let frameIndex = Int(frameNumber % UInt64(kMaxFramesInFlight))
    let yTexture = textureManager.getTexture(.y, frame: textureIndex)
    let cbcrTexture = textureManager.getTexture(.cbcr, frame: textureIndex)
    let alphaTexture = textureManager.getTexture(.alpha, frame: textureIndex)
    
    let allocator = commandAllocators[frameIndex]
    allocator.reset()
    
    autoreleasepool {
      if let currentDrawable {
        commandBuffer.beginCommandBuffer(allocator: allocator)

        renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture
        
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
          return
        }
        if let yTexture,
           let cbcrTexture,
           let alphaTexture {
          renderCommandEncoder.setRenderPipelineState(pipelineState)
          renderCommandEncoder.setArgumentTable(fragmentArgumentTable, stages: .fragment)
          renderCommandEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
          vertexArgumentTable.setAddress(vertexUniformBuffer.gpuAddress, index: 0)
          fragmentArgumentTable.setTexture(yTexture.gpuResourceID, index: 0)
          fragmentArgumentTable.setTexture(cbcrTexture.gpuResourceID, index: 1)
          fragmentArgumentTable.setTexture(alphaTexture.gpuResourceID, index: 2)
          fragmentArgumentTable.setSamplerState(samplerState.gpuResourceID, index: 0)
          renderCommandEncoder.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        renderCommandEncoder.endEncoding()
        commandBuffer.endCommandBuffer()
        commandQueue.waitForDrawable(currentDrawable)
        commandQueue.commit([commandBuffer])
        commandQueue.signalDrawable(currentDrawable)
        currentDrawable.present()
      }
    }
    
    commandQueue.signalEvent(sharedEvent, value: frameNumber)
  }
  
  func updateVertexUniform(textureWidth: CGFloat, textureHeight: CGFloat) {
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
    vertexUniformBuffer
      .contents()
      .bindMemory(to: SIMD2<Float>.self, capacity: 1)
      .pointee = scaleVector
    
    let loadAction: MTLLoadAction = if scaleX >= 1.0 && scaleY >= 1.0 {
      .dontCare
    } else {
      .clear
    }
    renderPassDescriptor.colorAttachments[0].loadAction = loadAction
  }
}

extension AlphaMetal4PerformanceVideoView: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewDelegate?.drawableSizeWillChange(size)
  }
  
  public func draw(in view: MTKView) {
    render()
  }
}
