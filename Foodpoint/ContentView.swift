import SwiftUI

struct ContentView : View {
    var body: some View {
        TabView {
            LocationView()
                .tabItem {
                    Label("Locations", systemImage: "tray.full")
                }

            AllItemsView()
                .tabItem {
                    Label("All Items", systemImage: "list.bullet")
                }

            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
        }
    }
}
