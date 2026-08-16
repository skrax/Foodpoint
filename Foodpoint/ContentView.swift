import SwiftUI

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
