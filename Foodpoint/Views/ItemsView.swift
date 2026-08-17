import SwiftUI
import FoodpointKit

/// "Items" tab: the flat, alphabetically sorted list of every saved product,
/// tapping through to `ItemDetailView` for quantity editing and nutrition.
///
/// Also the primary place to add a product: a "•••" toolbar menu (UX-1)
/// offers "Scan Barcode" and "Search by Name". "Scan Barcode" presents
/// `ScannerView` directly (`entryPoint: .scan`), which opens its camera on
/// appear. "Search by Name" presents `ProductSearchView` itself (UX-2 took
/// `ScannerView` back to scan-only, so it no longer hosts search UI) and,
/// once a barcode is chosen, hands it to `ScannerView` via
/// `entryPoint: .resolved(barcode:)` — a second, sequenced sheet (see the
/// `onDismiss` handoff in `body`) — so the same acquire/confirm/configure/
/// save flow already in `ScannerView` is reused rather than duplicated
/// here for search-originated products.
struct ItemsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingScanEntry = false
    @State private var isShowingSearchEntry = false
    @State private var isShowingResolvedProduct = false
    /// Barcode chosen from `ProductSearchView`, staged here across the
    /// hand-off from the search sheet to `ScannerView` (see `body`'s
    /// sequenced sheets) — cleared once the resolved-product sheet dismisses.
    @State private var resolvedSearchBarcode: String?

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
            .sheet(isPresented: $isShowingSearchEntry, onDismiss: {
                // Search sheet closed; if it closed because a result was
                // picked (rather than swiped away), hand that barcode to
                // ScannerView next. Sequenced via onDismiss rather than
                // presented together, since SwiftUI can't reliably show two
                // sheets from the same state update.
                if resolvedSearchBarcode != nil {
                    isShowingResolvedProduct = true
                }
            }) {
                ProductSearchView { barcode in
                    resolvedSearchBarcode = barcode
                    isShowingSearchEntry = false
                }
            }
            .sheet(isPresented: $isShowingResolvedProduct, onDismiss: {
                resolvedSearchBarcode = nil
            }) {
                if let resolvedSearchBarcode {
                    ScannerView(entryPoint: .resolved(barcode: resolvedSearchBarcode))
                }
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
