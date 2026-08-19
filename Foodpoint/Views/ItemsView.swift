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
/// `entryPoint: .resolved(barcode:)` so the same acquire/confirm/configure/
/// save flow already in `ScannerView` is reused rather than duplicated here
/// for search-originated products.
///
/// **FX-1**: this view used to drive that hand-off with two independent
/// `.sheet(isPresented:)` modifiers — the search sheet's `onDismiss` flipped
/// a second `Bool` to present `ScannerView` next. That produced a real,
/// reproducible bug: a blank sheet the first time a search result was
/// picked (closing it and retrying worked). Root cause was a timing race,
/// not a missing loading indicator (`ScannerView` already shows a
/// `ProgressView` while `fetchFoodData` is in flight) — presenting a
/// *second* sheet from inside the *first* sheet's own `onDismiss` asks
/// UIKit to start presenting a new view controller before it's necessarily
/// finished tearing down the previous one, and that race loses on the first
/// attempt more often than not. All three sheets (`.scan`, `.search`,
/// `.resolved(barcode:)`) are now driven by one `ActiveSheet?` and a single
/// `.sheet(item:)` below: switching the item's identity directly from
/// `.search` to `.resolved(barcode:)` (no intermediate `nil`/`onDismiss`
/// round-trip through our own code) lets SwiftUI own and sequence the
/// dismiss-then-present transition as one atomic update instead of two
/// hand-timed presentations racing each other.
struct ItemsView: View {
    /// Identifies which sheet (if any) `body` is currently presenting.
    /// Replaces the three separate `Bool`/staged-barcode `@State` vars this
    /// view used before FX-1 — see the type-level doc comment above for why
    /// a single `.sheet(item:)` over this enum, rather than two sequenced
    /// `.sheet(isPresented:)` modifiers, is what actually fixes the
    /// blank-screen bug.
    private enum ActiveSheet: Identifiable {
        case scan
        case search
        case resolved(barcode: String)

        var id: String {
            switch self {
            case .scan: "scan"
            case .search: "search"
            case .resolved(let barcode): "resolved:\(barcode)"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @State private var activeSheet: ActiveSheet?

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
                            activeSheet = .scan
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button {
                            activeSheet = .search
                        } label: {
                            Label("Search by Name", systemImage: "magnifyingglass")
                        }
                    } label: {
                        Label("Add Product", systemImage: "ellipsis")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .scan:
                    ScannerView(entryPoint: .scan)
                case .search:
                    ProductSearchView { barcode in
                        // Switching `activeSheet` directly from `.search` to
                        // `.resolved(barcode:)` — rather than dismissing to
                        // `nil` first and re-presenting from `onDismiss` —
                        // is the FX-1 fix: SwiftUI treats this as one
                        // dismiss-then-present transition it manages itself,
                        // instead of two sheets we'd otherwise have to
                        // hand-sequence and race.
                        activeSheet = .resolved(barcode: barcode)
                    }
                case .resolved(let barcode):
                    ScannerView(entryPoint: .resolved(barcode: barcode))
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
