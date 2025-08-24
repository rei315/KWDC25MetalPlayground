//
// View+.swift
// Playground
//
// Created by rei315 on 2025/07/26.
// Copyright © 2025 rei315. All rights reserved.
//

import SwiftUI

extension View {
  @ViewBuilder
  public func `if`<Content: View>(_ condition: Bool, @ViewBuilder transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
  
  @ViewBuilder
  public func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
    transform(self)
  }
}
