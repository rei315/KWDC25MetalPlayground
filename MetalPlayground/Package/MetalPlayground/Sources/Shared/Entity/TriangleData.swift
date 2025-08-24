//
// TriangleData.swift
// Hello Triangle Swift
//
// Created by rei315 on 2025/06/16.
// Copyright © 2025 rei315. All rights reserved.
//

import Foundation

package struct TriangleData {
  package var vertex0: VertexData
  package var vertex1: VertexData
  package var vertex2: VertexData
  
  package init(vertex0: VertexData, vertex1: VertexData, vertex2: VertexData) {
    self.vertex0 = vertex0
    self.vertex1 = vertex1
    self.vertex2 = vertex2
  }
}
