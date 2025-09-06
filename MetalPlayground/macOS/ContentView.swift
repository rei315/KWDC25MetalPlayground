//
// ContentView.swift
// MetalPlayground
//
// Created by rei315 on 2025/07/26.
// Copyright © 2025 rei315. All rights reserved.
//

import SwiftUI
import PlaygroundViews
import Shared

struct ContentView: View {
  @State var sideBarVisibility: NavigationSplitViewVisibility = .doubleColumn
  @State var selectedSideBarItem: SideBarItem = .hevc
  
  var body: some View {
    NavigationSplitView(
      columnVisibility: $sideBarVisibility
    ) {
      List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
        NavigationLink(
          item.title,
          value: item
        )
      }
    } detail: {
      switch selectedSideBarItem {
      case .hevc:
        HEVCPlayerView()
          .edgesIgnoringSafeArea(.all)
          .background(Color.green)
      case .hevcMetal4:
        HEVCPlayerMetal4View()
          .edgesIgnoringSafeArea(.all)
          .background(Color.green)
      case .hevcMetal4Performance:
        HEVCPlayerMetal4PerformanceView()
          .edgesIgnoringSafeArea(.all)
          .background(Color.green)
      }
    }
    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    .navigationTitle("")
  }
}

