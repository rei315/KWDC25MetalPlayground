//
// Platform.swift
// Playground
//
// Created by rei315 on 2025/07/26.
// Copyright © 2025 rei315. All rights reserved.
//

import SwiftUI

#if os(macOS)
import AppKit

public typealias PlatformViewController = NSViewController
public typealias PlatformRepresentableController = NSViewControllerRepresentable
public typealias PlatformButton = NSButton

#else
import UIKit

public typealias PlatformViewController = UIViewController
public typealias PlatformRepresentableController = UIViewControllerRepresentable
public typealias PlatformButton = UIButton

#endif
