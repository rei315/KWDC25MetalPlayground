//
// GridParams.swift
// HelloMetal
//
// Created by rei315 on 2025/06/18.
// Copyright © 2025 rei315. All rights reserved.
//

import Foundation

package struct GridParams {
  package var columns: UInt32
  package var rows: UInt32
  package var radius: Float
  
  package init(columns: UInt32, rows: UInt32, radius: Float) {
    self.columns = columns
    self.rows = rows
    self.radius = radius
  }
}
