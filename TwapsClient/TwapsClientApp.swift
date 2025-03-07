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
    /// The view model that manages the dynamic content (loaded Twaps)
    @StateObject private var dynamicViewModel = DynamicViewModel()
    
    var body: some Scene {
        // Main window - contains the ContentView for entering Twap URLs
        WindowGroup {
            ContentView()
                .environmentObject(dynamicViewModel)
        }
        
        // Dynamic window - displays the loaded Twap
        // This window is opened programmatically when a Twap is loaded
        Window("Dynamic View", id: "dynamic") {
            if let dynamicContent = dynamicViewModel.dynamicContent {
                // Display the loaded Twap
                dynamicContent
            } else {
                // Display a placeholder message if no Twap is loaded
                Text("No dynamic view loaded.")
            }
        }
    }
}
