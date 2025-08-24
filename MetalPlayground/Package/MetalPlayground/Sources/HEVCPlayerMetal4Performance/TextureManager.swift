//
// TextureManager.swift
// Playground
//
// Created by rei315 on 2025/07/20.
// Copyright © 2025 rei315. All rights reserved.
//

import Shared
import Metal
import AVFoundation

final class TextureManager {
  private let device: MTLDevice
  private let kMaxFramesInFlight: Int
  
  var yTextures: [MTLTexture?]
  var cbcrTextures: [MTLTexture?]
  var alphaTextures: [MTLTexture?]
  
  private(set) var residencySet: MTLResidencySet
  private var textureCache: CVMetalTextureCache?
  
  init(
    device: MTLDevice,
    kMaxFramesInFlight: Int
  ) {
    self.device = device
    self.kMaxFramesInFlight = kMaxFramesInFlight
    self.yTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    self.cbcrTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    self.alphaTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    let residencySetDesc = MTLResidencySetDescriptor()
    residencySetDesc.initialCapacity = kMaxFramesInFlight * 3
    guard let residencySet = try? device.makeResidencySet(descriptor: residencySetDesc) else {
      fatalError("Failed")
    }
    self.residencySet = residencySet
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
  }
}

// MARK: - public
extension TextureManager {
  func update(frame: UInt64, pixelBuffer: CVPixelBuffer) {
    let frame = currentFrameIndex(frame)
    var savedTextures: [MTLTexture] = []
    if let savedYTexture = yTextures[frame] {
      savedTextures.append(savedYTexture)
    }
    if let savedCBCRTexture = cbcrTextures[frame] {
      savedTextures.append(savedCBCRTexture)
    }
    if let savedAlphaTexture = alphaTextures[frame] {
      savedTextures.append(savedAlphaTexture)
    }
    residencySet.removeAllocations(savedTextures)
    
    let yTexture = makeTexture(pixelBuffer: pixelBuffer, plane: .y)
    let cbcrTexture = makeTexture(pixelBuffer: pixelBuffer, plane: .cbcr)
    let alphaTexture = makeTexture(pixelBuffer: pixelBuffer, plane: .alpha)
    yTextures[frame] = yTexture
    cbcrTextures[frame] = cbcrTexture
    alphaTextures[frame] = alphaTexture
    residencySet.addAllocations([yTexture, cbcrTexture, alphaTexture])
    residencySet.commit()
  }
  
  func getTexture(_ plane: PlaneType, frame: Int) -> MTLTexture? {
    switch plane {
    case .y:
      yTextures[safe: frame] ?? nil
    case .cbcr:
      cbcrTextures[safe: frame] ?? nil
    case .alpha:
      alphaTextures[safe: frame] ?? nil
    }
  }
  
  func reset() {
    yTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    cbcrTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    alphaTextures = Array(repeating: nil, count: kMaxFramesInFlight)
    residencySet.removeAllAllocations()
    residencySet.commit()
    if let textureCache {
      CVMetalTextureCacheFlush(textureCache, 0)
    }
  }
  
  func flush() {
    yTextures.removeAll()
    cbcrTextures.removeAll()
    alphaTextures.removeAll()
    residencySet.removeAllAllocations()
    residencySet.commit()
    residencySet.endResidency()
    if let textureCache {
      CVMetalTextureCacheFlush(textureCache, 0)
    }
  }
  
  func yTextureSize() -> (Int, Int) {
    guard let yTexture = yTextures.first ?? nil else {
      return (.zero, .zero)
    }
    return (yTexture.width, yTexture.height)
  }
}

// MARK: - private
extension TextureManager {
  private func currentFrameIndex(_ frame: UInt64) -> Int {
    let index = frame % UInt64(kMaxFramesInFlight)
    return Int(index)
  }
  
  private func makeTexture(pixelBuffer: CVPixelBuffer, plane: PlaneType) -> MTLTexture {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane.plane)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane.plane)
    var cvTexture: CVMetalTexture?
    CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault,
      textureCache!,
      pixelBuffer,
      nil,
      plane.pixelFormat,
      width,
      height,
      plane.plane,
      &cvTexture
    )
    return CVMetalTextureGetTexture(cvTexture!)!
  }
}

// MARK: - entity
extension TextureManager {
  enum PlaneType {
    case y
    case cbcr
    case alpha
    
    var plane: Int {
      switch self {
      case .y:
        0
      case .cbcr:
        1
      case .alpha:
        2
      }
    }
    
    var pixelFormat: MTLPixelFormat {
      switch self {
      case .y:
        .r8Unorm
      case .cbcr:
        .rg8Unorm
      case .alpha:
        .r8Unorm
      }
    }
  }
}
