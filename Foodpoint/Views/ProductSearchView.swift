import SwiftUI
import FoodpointKit

/// Sheet for finding a product by name when there's no barcode to scan —
/// fresh produce, bulk goods, and other unlabeled groceries. Search runs
/// against Open Food Facts directly (`ProductLookup.search`); picking a
/// result hands its barcode back to the caller rather than the already-
/// fetched `Product`, so it re-resolves through the exact same path a scan
/// would (`ScannerView.fetchFoodData`) instead of a separate code path.
///
/// **This view never dismisses itself on selection** — picking a result
/// only calls `onSelect`; the caller decides what "done" means and closes
/// this sheet however that requires. This was a real bug: an earlier
/// version called `dismiss()` right after `onSelect` unconditionally, which
/// worked for `MealCompositionEditorView` (which flips its own `isPresented`
/// bool in `onSelect` too — redundant with the internal `dismiss()`, but
/// harmless) but broke `ItemsView`, which reassigns a shared `activeSheet`
/// item to a *different* case (`.resolved(barcode:)`) inside `onSelect` to
/// transition straight to the configure screen — the internal `dismiss()`
/// fired immediately after raced that reassignment and won, snapping
/// `activeSheet` back to `nil` before the next sheet ever appeared: this
/// sheet just closed, with nothing saved, back to an empty Items list. If
/// you add a new caller, remember it owns dismissal entirely on selection.
struct ProductSearchView: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    /// Barcode of the result currently pushed for nutrition inspection, or
    /// `nil` when nothing is being inspected. Drives
    /// `.navigationDestination(item:)` on this view's own `NavigationStack`
    /// rather than a sheet, so popping back (button or edge swipe) lands on
    /// this same results list without re-running `search()` — `results`
    /// and `query` are untouched by the push/pop. Tracked by barcode
    /// (`Product.id`) rather than the `Product` itself since `Product`
    /// isn't `Hashable`, which `.navigationDestination(item:)` requires.
    @State private var inspectedProductID: String?

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if results.isEmpty {
                    ContentUnavailableView(
                        hasSearched ? "No Matches" : "Search by Name",
                        systemImage: "magnifyingglass",
                        description: Text(hasSearched
                            ? "No products matched \"\(query)\"."
                            : "Find a product that doesn't have a barcode to scan, like fresh produce.")
                    )
                } else {
                    List(results) { product in
                        resultRow(product)
                    }
                }
            }
            .navigationTitle("Search by Name")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "e.g. banana")
            .onSubmit(of: .search, search)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $inspectedProductID) { barcode in
                if let product = results.first(where: { $0.id == barcode }) {
                    SearchResultDetailView(product: product)
                }
            }
        }
    }

    /// A plain `HStack` with `.contentShape(Rectangle())` +
    /// `.onTapGesture` for the row's primary action (select-and-proceed),
    /// plus a separate `.buttonStyle(.plain)` `Button` for the secondary
    /// action (push the nutrition detail view) — the same fix for nested
    /// tappable controls that `PackageVariantsView.row(for:)` uses, applied
    /// here so the info button doesn't fight the row's own tap gesture.
    private func resultRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            if let url = product.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading) {
                Text(product.name ?? "Unknown Product")
                    .font(.headline)
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                inspectedProductID = product.id
            } label: {
                Image(systemName: "info.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(product.id)
        }
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let products = try await ProductLookup.search(query: trimmed)
                await MainActor.run {
                    self.results = products
                    self.isSearching = false
                    self.hasSearched = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                    self.hasSearched = true
                }
            }
        }
    }
}
