//
// MetalRenderer.swift
// Hello Triangle Swift
//
// Created by rei315 on 2025/06/16.
// Copyright © 2025 rei315. All rights reserved.
//

import Metal
import MetalKit
import simd
import Shared

@MainActor
public final class MetalRenderer: NSObject {
  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private var frameNumber: UInt64 = 0
  private var sharedEvent: MTLSharedEvent!
  private var viewportSize = SIMD2<UInt32>(0, 0)
  private var viewportSizeBuffer: MTLBuffer!
  private var gridParamsBuffer: MTLBuffer!
  private var triangleVertexBuffers: [MTLBuffer] = []
  private var renderPipelineState: MTLRenderPipelineState!
  private var triangleCount: Int = .zero
  
  private let radius: Float = 200.0
  private let kMaxFramesInFlight = 3
  
  public init(view: MTKView) {
    self.device = view.device!
    self.commandQueue = device.makeCommandQueue()!
    super.init()
    createRenderPipeline(pixelFormat: view.colorPixelFormat)
    createDataBuffers()
    createSharedEvent()
    updateViewportSize(view.drawableSize)
  }
  
  private func createRenderPipeline(pixelFormat: MTLPixelFormat) {
    let library = try! device.makeDefaultLibrary(bundle: SharedResource.bundle)
    let vertexFunction = library.makeFunction(name: "helloMetalVertex")!
    let fragmentFunction = library.makeFunction(name: "helloMetalFragment")!
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Basic Metal render pipeline"
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
    
    renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }
  
  private func createSharedEvent() {
    sharedEvent = device.makeSharedEvent()
    sharedEvent.signaledValue = frameNumber
  }
  
  private func createDataBuffers() {
    triangleVertexBuffers = (0..<kMaxFramesInFlight).map { _ in
      device.makeBuffer(length: MemoryLayout<TriangleData>.size, options: .storageModeShared)!
    }
    
    viewportSizeBuffer = device.makeBuffer(
      length: MemoryLayout<SIMD2<UInt32>>.size,
      options: .storageModeShared
    )
    gridParamsBuffer = device.makeBuffer(length: MemoryLayout<GridParams>.size, options: .storageModeShared)
  }
  
  private func updateGridParams(viewSize: CGSize) {
    let sideLength = sqrt(3) * radius
    let height = 1.5 * radius
    
    let columns = UInt32(max(1, floor(viewSize.width / CGFloat(sideLength))))
    let rows = UInt32(max(1, floor(viewSize.height / CGFloat(height))))
    triangleCount = Int(columns * rows)
    
    var gridParams = GridParams(columns: columns, rows: rows, radius: radius)
    memcpy(gridParamsBuffer.contents(), &gridParams, MemoryLayout<GridParams>.size)
  }
  
  private func configureVertexData(buffer: MTLBuffer) {
    let rotation: Float = Float(frameNumber % 360)
    var triangleData: TriangleData = triangleRedGreenBlue(radius: radius, rotationInDegrees: rotation)
    
    memcpy(buffer.contents(), &triangleData, MemoryLayout<TriangleData>.size)
  }
  
  func updateViewportSize(_ size: CGSize) {
    viewportSize.x = UInt32(size.width)
    viewportSize.y = UInt32(size.height)
    
    memcpy(viewportSizeBuffer.contents(), &viewportSize, MemoryLayout<SIMD2<UInt32>>.size)
    
    updateGridParams(viewSize: size)
  }
  
  func renderFrame(to view: MTKView) {
    guard let renderPassDescriptor = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable else { return }
    
    frameNumber += 1
    let frameIndex = Int(frameNumber % UInt64(kMaxFramesInFlight))
    let vertexBuffer = triangleVertexBuffers[frameIndex]
    
    configureVertexData(buffer: vertexBuffer)
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    commandBuffer.label = "Command buffer for frame \(frameNumber)"
    
    if frameNumber >= kMaxFramesInFlight {
      let waitValue = frameNumber - UInt64(kMaxFramesInFlight)
      commandBuffer.encodeWaitForEvent(sharedEvent, value: waitValue)
    }
    
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    renderEncoder.label = "Render pass for frame \(frameNumber)"
    
    let viewport = MTLViewport(
      originX: 0,
      originY: 0,
      width: Double(viewportSize.x),
      height: Double(viewportSize.y),
      znear: 0.0,
      zfar: 1.0
    )
    renderEncoder.setViewport(viewport)
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: InputBufferIndex.vertexData.rawValue)
    renderEncoder.setVertexBuffer(viewportSizeBuffer, offset: 0, index: InputBufferIndex.viewportSize.rawValue)
    renderEncoder.setVertexBuffer(gridParamsBuffer, offset: 0, index: InputBufferIndex.gridParams.rawValue)
    
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: triangleCount)
    renderEncoder.endEncoding()
    
    commandBuffer.encodeSignalEvent(sharedEvent, value: frameNumber)
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

}

extension MetalRenderer: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    updateViewportSize(size)
  }
  
  public func draw(in view: MTKView) {
    renderFrame(to: view)
  }
}
