import SwiftUI
import FoodpointKit

/// "Items" tab: the flat, alphabetically sorted list of every saved product,
/// tapping through to `ItemDetailView` for quantity editing and nutrition.
///
/// Also the primary place to add a product: a "•••" toolbar menu (UX-1)
/// offers "Scan Barcode" and "Search by Name", both presenting `ScannerView`
/// as a sheet (parameterized via `ScannerView.EntryPoint` to immediately
/// open the matching flow) rather than duplicating its acquire/confirm/
/// configure/save logic here.
struct ItemsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingScanEntry = false
    @State private var isShowingSearchEntry = false

    private var sortedItems: [FoodItem] {
        appState.pantry.items.sorted { ($0.product.name ?? "") < ($1.product.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        "No Products",
                        systemImage: "shippingbox",
                        description: Text("Products you scan appear here.")
                    )
                } else {
                    List(sortedItems) { item in
                        row(for: item)
                    }
                }
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingScanEntry = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button {
                            isShowingSearchEntry = true
                        } label: {
                            Label("Search by Name", systemImage: "magnifyingglass")
                        }
                    } label: {
                        Label("Add Product", systemImage: "ellipsis")
                    }
                }
            }
            .sheet(isPresented: $isShowingScanEntry) {
                ScannerView(entryPoint: .scan)
            }
            .sheet(isPresented: $isShowingSearchEntry) {
                ScannerView(entryPoint: .search)
            }
        }
    }

    private func row(for item: FoodItem) -> some View {
        NavigationLink {
            ItemDetailView(itemID: item.id)
        } label: {
            ProductRow(product: item.product, quantity: item.quantity, unitLabel: item.unit.label)
        }
    }
}
