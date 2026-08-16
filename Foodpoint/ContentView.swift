import SwiftUI

struct ContentView : View {
    var body: some View {
        TabView {
            LocationView()
                .tabItem {
                    Label("Locations", systemImage: "tray.full")
                }

            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
        }
    }
}
