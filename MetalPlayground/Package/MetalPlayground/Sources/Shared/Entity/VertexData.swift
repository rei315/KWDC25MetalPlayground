//
// VertexData.swift
// Hello Triangle Swift
//
// Created by rei315 on 2025/06/16.
// Copyright © 2025 rei315. All rights reserved.
//

import simd
import Foundation

package struct VertexData {
  package var position: SIMD2<Float>
  package var color: SIMD4<Float>
  
  package init(position: SIMD2<Float>, color: SIMD4<Float>) {
    self.position = position
    self.color = color
  }
}
