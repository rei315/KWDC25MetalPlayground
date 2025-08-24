//
// HEVCPlayerView.swift
// MetalPlayground
//
// Created by rei315 on 2025/06/30.
// Copyright © 2025 rei315. All rights reserved.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

import MetalKit
import SwiftUI
import HEVCPlayer
import UniformTypeIdentifiers
import Shared

public struct HEVCPlayerView: PlatformRepresentableController {
  public init() {}
  
#if os(macOS)
  public func makeNSViewController(context: Context) -> PlatformViewController {
    HEVCPlayerViewController()
  }
  
  public func updateNSViewController(_ nsViewController: PlatformViewController, context: Context) {}
#elseif os(iOS)
  public func makeUIViewController(context: Context) -> PlatformViewController {
    HEVCPlayerViewController()
  }
  public func updateUIViewController(_ uiViewController: PlatformViewController, context: Context) {
    
  }
#endif
}

public class HEVCPlayerViewController: PlatformViewController {
  lazy var metalView: AlphaMetalVideoView = .init(device: MTLCreateSystemDefaultDevice()!)
  lazy var player: AlphaVideoPlayer = .init(renderTarget: metalView)
  let uploadButton: PlatformButton = .init()
  private var continuation: CheckedContinuation<URL?, Never>?
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setupView()
  }
  
  private func setupView() {
    uploadButton: do {
#if os(macOS)
      uploadButton.title = "Select Video"
      uploadButton.image = NSImage(
        systemSymbolName: "photo.badge.plus",
        accessibilityDescription: nil
      )?.withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
      uploadButton.imagePosition = .imageLeft
      uploadButton.target = self
      uploadButton.action = #selector(uploadButtonTapped)
#elseif os(iOS)
      var config = UIButton.Configuration.plain()
      config.title = "Select Video"
      config.image = .init(
        systemName: "photo.badge.plus"
      )?.withConfiguration(
        UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
      )
      config.imagePadding = 8
      uploadButton.configuration = config
      uploadButton.addTarget(
        self,
        action: #selector(uploadButtonTapped),
        for: .touchUpInside
      )
#endif

      uploadButton.translatesAutoresizingMaskIntoConstraints = false
    }
    metalView: do {
      metalView.translatesAutoresizingMaskIntoConstraints = false
    }
    addView: do {
      view.addSubview(metalView)
      view.addSubview(uploadButton)
    }
    layout: do {
      NSLayoutConstraint.activate([
        uploadButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        
        metalView.topAnchor.constraint(equalTo: view.topAnchor),
        metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      ])
    }
  }

  @objc private func uploadButtonTapped() {
    Task { @MainActor in
#if os(macOS)
      guard let url = await selectVideo() else {
        return
      }
      playVideo(url: url)
#elseif os(iOS)
      guard let url = await selectVideo(from: self) else {
        return
      }
      let didStartAccessing = url.startAccessingSecurityScopedResource()
      
      defer {
        if didStartAccessing {
          url.stopAccessingSecurityScopedResource()
        }
      }
      playVideo(url: url)
#endif
    }
  }

  private func playVideo(url: URL) {
    player.replace(url)
  }
}

#if os(macOS)
extension HEVCPlayerViewController {
  private func selectVideo() async -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.video, .quickTimeMovie]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    let result = await panel.begin()
    guard result == .OK,
          let url = panel.url else {
      return nil
    }
    return url
  }
}
#endif

#if os(iOS)
extension HEVCPlayerViewController: UIDocumentPickerDelegate {
  private func selectVideo(from presenter: UIViewController) async -> URL? {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.movie, .video, .quickTimeMovie],
        asCopy: false
      )
      picker.allowsMultipleSelection = false
      picker.delegate = self
      presenter.present(picker, animated: true)
    }
  }
  
  public func documentPicker(_ controller: UIDocumentPickerViewController,
                      didPickDocumentsAt urls: [URL]) {
    continuation?.resume(returning: urls.first)
    continuation = nil
  }
  
  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    continuation?.resume(returning: nil)
    continuation = nil
  }
}
#endif
