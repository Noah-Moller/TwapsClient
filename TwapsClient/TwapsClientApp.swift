//
//  TwapsClientApp.swift
//  TwapsClient
//
//  Created by Noah Moller on 7/3/2025.
//

import SwiftUI

/**
 * TwapsClientApp
 *
 * The main app structure for the TwapsClient.
 * This app allows users to load and display Twaps from a server.
 *
 * The app consists of two windows:
 * 1. The main window, which contains the ContentView for entering Twap URLs
 * 2. A dynamic window that displays the loaded Twap
 */

@main
struct TwapsClientApp: App {
    @StateObject private var dynamicViewModel = DynamicViewModel.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dynamicViewModel)
        }
        Window("Dynamic View", id: "dynamic") {
            DynamicContentView()
                .environmentObject(dynamicViewModel)
        }
    }
}
