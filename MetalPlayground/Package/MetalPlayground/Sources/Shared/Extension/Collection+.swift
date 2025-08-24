//
// Collection+.swift
// Playground
//
// Created by rei315 on 2025/07/21.
// Copyright © 2025 rei315. All rights reserved.
//

import Foundation

extension Collection {
  package subscript (safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
