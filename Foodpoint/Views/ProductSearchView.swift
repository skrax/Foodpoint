import SwiftUI
import FoodpointKit

/// Sheet for finding a product by name when there's no barcode to scan —
/// fresh produce, bulk goods, and other unlabeled groceries. Search runs
/// against Open Food Facts directly (`ProductLookup.search`); picking a
/// result hands its barcode back to the caller rather than the already-
/// fetched `Product`, so it re-resolves through the exact same path a scan
/// would (`ScannerView.fetchFoodData`) instead of a separate code path.
struct ProductSearchView: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

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
                        Button {
                            onSelect(product.id)
                            dismiss()
                        } label: {
                            resultRow(product)
                        }
                        .buttonStyle(.plain)
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
        }
    }

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
