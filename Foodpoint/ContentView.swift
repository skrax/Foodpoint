import SwiftUI

/// Root tab bar: browse saved items, scan a new one, or compose a meal.
/// "Meals" (MK-2) is a thin placeholder for now — see `MealsView`'s doc
/// comment — that exists purely so `MealCompositionEditorView` is reachable
/// before the real Meals tab (day timeline, templates) lands in MK-4/MK-5.
struct ContentView : View {
    var body: some View {
        TabView {
            ItemsView()
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }

            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }

            MealsView()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }
        }
    }
}
