//
// SideBarItem.swift
// Playground
//
// Created by rei315 on 2025/07/26.
// Copyright © 2025 rei315. All rights reserved.
//

import Foundation

public enum SideBarItem: String, Identifiable, CaseIterable {
  public var id: String { rawValue }
  
  case hevc
  case hevcMetal4
  case hevcMetal4Performance
  case helloMetal
  case helloMetal4
  
  public var title: String {
    switch self {
    case .helloMetal:
      "Hello Metal"
    case .helloMetal4:
      "Hello Metal4"
    case .hevc:
      "HEVCPlayer"
    case .hevcMetal4:
      "HEVCPlayer Metal4"
    case .hevcMetal4Performance:
      "HEVCPlayer Metal4 Performance"
    }
  }
}
