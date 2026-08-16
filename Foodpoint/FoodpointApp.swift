//
//  FoodpointApp.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 03.08.26.
//

import SwiftUI
import FoodpointKit

/// App entry point. Injects the single shared `AppState` into the view hierarchy.
@main
struct FoodpointApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppState.shared)
        }
    }
}
