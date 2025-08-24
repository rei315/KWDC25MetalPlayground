//
// Metal4Renderer.swift
// HelloMetal
//
// Created by rei315 on 2025/06/18.
// Copyright © 2025 rei315. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import simd
import Shared

@MainActor
public final class Metal4Renderer: NSObject {
  private var device: MTLDevice!
  private var commandQueue: MTL4CommandQueue!
  private var commandAllocators: [MTL4CommandAllocator] = []
  private var commandBuffer: MTL4CommandBuffer!
  private var argumentTable: MTL4ArgumentTable!
  private var residencySet: MTLResidencySet!
  private var sharedEvent: MTLSharedEvent!
  private var frameNumber: UInt64 = 0
  private var viewportSize = simd_uint2()
  private var viewportSizeBuffer: MTLBuffer!
  private var gridParamsBuffer: MTLBuffer!
  private var triangleVertexBuffers: [MTLBuffer] = []
  private var renderPipelineState: MTLRenderPipelineState!
  private var triangleCount: Int = .zero
  
  private let radius: Float = 200.0
  private let kMaxFramesInFlight = 3
  
  public init(view: MTKView) {
    self.device = view.device
    view.preferredFramesPerSecond = 60
    self.commandQueue = device.makeMTL4CommandQueue()
    self.commandBuffer = device.makeCommandBuffer()
    super.init()
    createRenderPipeline(pixelFormat: view.colorPixelFormat)
    createDataBuffers()
    createArgumentTable()
    createResidencySet()
    createCommandAllocators()
    configureResidencySet(view: view)
    createSharedEvent()
    updateViewportSize(view.drawableSize)
  }
  
  private func createDataBuffers() {
    triangleVertexBuffers = (0..<kMaxFramesInFlight).map { _ in
      device.makeBuffer(length: MemoryLayout<TriangleData>.size, options: .storageModeShared)!
    }
    viewportSizeBuffer = device.makeBuffer(length: MemoryLayout<simd_uint2>.size, options: .storageModeShared)
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
  
  private func createRenderPipeline(pixelFormat: MTLPixelFormat) {
    let library = try! device.makeDefaultLibrary(bundle: SharedResource.bundle)
    let compiler = try! device.makeCompiler(descriptor: MTL4CompilerDescriptor())
    
    let vertexDescriptor = MTL4LibraryFunctionDescriptor()
    vertexDescriptor.library = library
    vertexDescriptor.name = "helloMetalVertex"
    
    let fragmentDescriptor = MTL4LibraryFunctionDescriptor()
    fragmentDescriptor.library = library
    fragmentDescriptor.name = "helloMetalFragment"
    
    let pipelineDescriptor = MTL4RenderPipelineDescriptor()
    pipelineDescriptor.label = "Basic Metal 4 render pipeline"
    pipelineDescriptor.vertexFunctionDescriptor = vertexDescriptor
    pipelineDescriptor.fragmentFunctionDescriptor = fragmentDescriptor
    pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
    renderPipelineState = try! compiler.makeRenderPipelineState(descriptor: pipelineDescriptor)
  }
  
  private func createArgumentTable() {
    let descriptor = MTL4ArgumentTableDescriptor()
    descriptor.maxBufferBindCount = 3
    argumentTable = try! device.makeArgumentTable(descriptor: descriptor)
  }
  
  private func createResidencySet() {
    let descriptor = MTLResidencySetDescriptor()
    residencySet = try! device.makeResidencySet(descriptor: descriptor)
  }
  
  private func createCommandAllocators() {
    commandAllocators = (0..<kMaxFramesInFlight).map { _ in
      device.makeCommandAllocator()!
    }
  }
  
  private func createSharedEvent() {
    sharedEvent = device.makeSharedEvent()
    sharedEvent.signaledValue = frameNumber
  }
  
  private func configureResidencySet(view: MTKView) {
    commandQueue.addResidencySet(residencySet)
    if let metalLayer = view.layer as? CAMetalLayer {
      commandQueue.addResidencySet(metalLayer.residencySet)
    }
    residencySet.addAllocations(triangleVertexBuffers)
    residencySet.addAllocation(viewportSizeBuffer)
    residencySet.addAllocation(gridParamsBuffer)
    residencySet.commit()
  }
  
  func updateViewportSize(_ size: CGSize) {
    viewportSize = simd_uint2(UInt32(size.width), UInt32(size.height))
    memcpy(viewportSizeBuffer.contents(), &viewportSize, MemoryLayout<simd_uint2>.size)
    
    updateGridParams(viewSize: size)
  }
  
  func renderFrame(to view: MTKView) {
    guard let drawable = view.currentDrawable else {
      return
    }
    guard let renderPassDescriptor = view.currentMTL4RenderPassDescriptor else {
      return
    }
    
    frameNumber += 1
    
    if frameNumber >= kMaxFramesInFlight {
      let waitValue = frameNumber - UInt64(kMaxFramesInFlight)
      _ = sharedEvent.wait(untilSignaledValue: waitValue, timeoutMS: 10)
    }
    
    let frameIndex = Int(frameNumber % UInt64(kMaxFramesInFlight))
    let allocator = commandAllocators[frameIndex]
    allocator.reset()
    
    commandBuffer.beginCommandBuffer(allocator: allocator)
    commandBuffer.label = "Command Buffer #\(frameNumber)"
    
    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    encoder.label = "Render Encoder #\(frameNumber)"
    
    encoder.setViewport(MTLViewport(
      originX: 0,
      originY: 0,
      width: Double(viewportSize.x),
      height: Double(viewportSize.y),
      znear: 0,
      zfar: 1
    ))
    encoder.setRenderPipelineState(renderPipelineState)
    encoder.setArgumentTable(argumentTable, stages: .vertex)
    
    let vertexBuffer = triangleVertexBuffers[frameIndex]
    configureVertexData(for: vertexBuffer)
    
    argumentTable.setAddress(vertexBuffer.gpuAddress, index: InputBufferIndex.vertexData.rawValue)
    argumentTable.setAddress(viewportSizeBuffer.gpuAddress, index: InputBufferIndex.viewportSize.rawValue)
    argumentTable.setAddress(gridParamsBuffer.gpuAddress, index: InputBufferIndex.gridParams.rawValue)
    
    encoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: triangleCount)
    encoder.endEncoding()
    
    commandBuffer.endCommandBuffer()
    commandQueue.waitForDrawable(drawable)
    commandQueue.commit([commandBuffer])
    commandQueue.signalDrawable(drawable)
    drawable.present()
    
    commandQueue.signalEvent(sharedEvent, value: frameNumber)
  }
  
  private func configureVertexData(for buffer: MTLBuffer) {
    let rotation: UInt16 = UInt16(frameNumber % 360)
    var triangleData: TriangleData = triangleRedGreenBlue(radius: radius, rotationInDegrees: Float(rotation))
    
    memcpy(buffer.contents(), &triangleData, MemoryLayout<TriangleData>.size)
  }
}

extension Metal4Renderer: MTKViewDelegate {
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    updateViewportSize(size)
  }
  
  public func draw(in view: MTKView) {
    autoreleasepool {
      renderFrame(to: view)
    }
  }
}
