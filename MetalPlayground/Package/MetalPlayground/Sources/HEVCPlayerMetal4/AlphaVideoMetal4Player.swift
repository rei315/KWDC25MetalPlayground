//
// AlphaVideoMetal4Player.swift
// HEVCPlayer
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

import AVFoundation
import CoreVideo
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
public final class AlphaVideoMetal4Player {
  private let player: AVPlayer = .init()
  private let output: AVPlayerItemVideoOutput
  private var displayLink: CADisplayLink?
  private let renderTarget: AlphaMetal4VideoView
  private var didPlayToEndTimeNotification: NSObjectProtocol?
  private var didEnderBackgroundNotification: NSObjectProtocol?
  private var didBecomeActiveNotification: NSObjectProtocol?
  
  public init(renderTarget: AlphaMetal4VideoView) {
    self.renderTarget = renderTarget
    
    let attrs: [String: Int] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar)
    ]
    output = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
#if os(macOS)
    displayLink = renderTarget.displayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
#elseif os(iOS)
    displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
#endif
    displayLink?.add(to: .current, forMode: .common)
    displayLink?.preferredFrameRateRange = .init(minimum: 60, maximum: 120, __preferred: 60)
    displayLink?.isPaused = true
  }
  
  isolated deinit {
    displayLink?.invalidate()
    displayLink = nil
  }
}

// MARK: - public
extension AlphaVideoMetal4Player {
  public func pause() {
    displayLink?.isPaused = true
    player.pause()
  }
  
  public func replace(_ url: URL) {
    reset()
    let item = AVPlayerItem(url: url)
    item.add(output)
    player.replaceCurrentItem(with: item)
    addObserver(item: item)
    displayLink?.isPaused = false
    player.play()
  }
}

// MARK: - private
extension AlphaVideoMetal4Player {
  @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
    frameUpdate()
  }
  
  private func frameUpdate() {
    let time = output.itemTime(forHostTime: CACurrentMediaTime())
    guard output.hasNewPixelBuffer(forItemTime: time),
          let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
    else {
      return
    }
    
    renderTarget.updateTextures(pixelBuffer: buffer)
  }
  
  private func removeCurrentItem() {
    if let oldItem = player.currentItem {
      oldItem.remove(output)
    }
    if let observer = didPlayToEndTimeNotification {
      NotificationCenter.default.removeObserver(observer)
      didPlayToEndTimeNotification = nil
    }
    if let observer = didEnderBackgroundNotification {
      NotificationCenter.default.removeObserver(observer)
      didEnderBackgroundNotification = nil
    }
    if let observer = didBecomeActiveNotification {
      NotificationCenter.default.removeObserver(observer)
      didBecomeActiveNotification = nil
    }
  }
  private func reset() {
    displayLink?.isPaused = true
    removeCurrentItem()
    self.renderTarget.reset()
  }
  private func finish() {
    displayLink?.isPaused = true
    removeCurrentItem()
    self.renderTarget.finish()
  }
  private func addObserver(item: AVPlayerItem) {
    didPlayToEndTimeNotification: do {
      let didPlayToEndTimeNotification = NotificationCenter.default.addObserver(
        forName: AVPlayerItem.didPlayToEndTimeNotification,
        object: item,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.finish()
        }
      }
      self.didPlayToEndTimeNotification = didPlayToEndTimeNotification
    }
    
    didEnderBackgroundNotification: do {
      let didEnderBackground: Notification.Name
  #if os(macOS)
      didEnderBackground = NSApplication.didResignActiveNotification
  #elseif os(iOS)
      didEnderBackground = UIApplication.didEnterBackgroundNotification
  #endif
      let didEnderBackgroundNotification = NotificationCenter.default.addObserver(
        forName: didEnderBackground,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          if self?.player.timeControlStatus == .playing {
            self?.player.pause()
          }
        }
      }
      self.didEnderBackgroundNotification = didEnderBackgroundNotification
    }
    
    didBecomeActiveNotification: do {
      let didBecomeActive: Notification.Name
  #if os(macOS)
      didBecomeActive = NSApplication.didBecomeActiveNotification
  #elseif os(iOS)
      didBecomeActive = UIApplication.didBecomeActiveNotification
  #endif
      let didBecomeActiveNotification = NotificationCenter.default.addObserver(
        forName: didBecomeActive,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          if self?.player.timeControlStatus == .paused {
            self?.player.play()
          }
        }
      }
      self.didBecomeActiveNotification = didBecomeActiveNotification
    }
  }
}
