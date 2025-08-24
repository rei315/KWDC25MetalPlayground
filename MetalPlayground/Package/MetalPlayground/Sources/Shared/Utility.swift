//
// Utility.swift
// Playground
//
// Created by rei315 on 2025/07/03.
// Copyright © 2025 rei315. All rights reserved.
//

import simd
import Foundation

package func triangleRedGreenBlue(radius: Float, rotationInDegrees: Float) -> TriangleData {
  let angle0 = rotationInDegrees * .pi / 180.0
  let angle1 = angle0 + (2.0 * .pi / 3.0)
  let angle2 = angle0 + (4.0 * .pi / 3.0)
  
  let position0 = SIMD2<Float>(radius * cos(angle0), radius * sin(angle0))
  let position1 = SIMD2<Float>(radius * cos(angle1), radius * sin(angle1))
  let position2 = SIMD2<Float>(radius * cos(angle2), radius * sin(angle2))
  
  let red = SIMD4<Float>(1, 0, 0, 1)
  let green = SIMD4<Float>(0, 1, 0, 1)
  let blue = SIMD4<Float>(0, 0, 1, 1)
  
  let vertex0 = VertexData(position: position0, color: red)
  let vertex1 = VertexData(position: position1, color: green)
  let vertex2 = VertexData(position: position2, color: blue)
  
  return TriangleData(vertex0: vertex0, vertex1: vertex1, vertex2: vertex2)
}
