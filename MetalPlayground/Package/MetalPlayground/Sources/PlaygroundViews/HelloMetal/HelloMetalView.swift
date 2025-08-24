//
// HelloMetalView.swift
// Hello Triangle Swift
//
// Created by rei315 on 2025/06/16.
// Copyright © 2025 rei315. All rights reserved.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

import MetalKit
import SwiftUI
import HelloMetal
import Shared

public struct HelloMetalView: PlatformRepresentableController {
  public init() {}
#if os(macOS)
  public func makeNSViewController(context: Context) -> PlatformViewController {
    HelloMetalViewController()
  }
  
  public func updateNSViewController(_ nsViewController: PlatformViewController, context: Context) {}
#elseif os(iOS)
  public func makeUIViewController(context: Context) -> PlatformViewController {
    HelloMetalViewController()
  }
  public func updateUIViewController(_ uiViewController: PlatformViewController, context: Context) {
    
  }
#endif
}

public class HelloMetalViewController: PlatformViewController {
  let mtkView: MTKView = .init()
  var renderer: MetalRenderer!
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setupView()
  }
  
  private func setupView() {
    metalView: do {
      mtkView.device = MTLCreateSystemDefaultDevice()
      mtkView.translatesAutoresizingMaskIntoConstraints = false
      renderer = MetalRenderer(view: mtkView)
      mtkView.delegate = renderer
    }
    addView: do {
      view.addSubview(mtkView)
    }
    layout: do {
      NSLayoutConstraint.activate([
        mtkView.topAnchor.constraint(equalTo: view.topAnchor),
        mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        mtkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        mtkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      ])
    }
  }
}
