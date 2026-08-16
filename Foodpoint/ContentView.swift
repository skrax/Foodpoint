import SwiftUI

/// Root tab bar: browse saved items, or scan a new one.
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
        }
    }
}
