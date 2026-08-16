import SwiftUI

struct LocationDetailView: View {
    let locationID: Location.ID
    @Environment(AppState.self) private var appState
    @State private var isShowingScanner = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var location: Location? {
        appState.locations.first { $0.id == locationID }
    }

    var body: some View {
        Group {
            if let location, !location.items.isEmpty {
                List {
                    ForEach(location.items) { item in
                        row(for: item)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            appState.removeItem(location.items[index].id, fromLocationWithID: locationID)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Products",
                    systemImage: "shippingbox",
                    description: Text("Scan a barcode to add products here.")
                )
            }
        }
        .navigationTitle(location?.name ?? "Location")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    errorMessage = nil
                    isShowingScanner = true
                } label: {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Fetching product details...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            ZStack {
                FastFoodBarcodeScanner { barcode in
                    isShowingScanner = false
                    fetchAndAdd(barcode: barcode)
                }
                .ignoresSafeArea()

                ViewfinderOverlay()
                    .ignoresSafeArea()
            }
        }
        .alert("Scan Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(for item: LocationItem) -> some View {
        HStack {
            NavigationLink {
                ScrollView {
                    ProductDetailCard(product: item.product)
                }
                .navigationTitle(item.product.productName ?? "Product")
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                VStack(alignment: .leading) {
                    Text(item.product.productName ?? "Unknown Product")
                        .font(.headline)
                    if let brands = item.product.brands {
                        Text(brands)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Stepper(
                "\(item.quantity)",
                value: Binding(
                    get: { item.quantity },
                    set: { appState.setQuantity($0, forItemID: item.id, inLocationWithID: locationID) }
                ),
                in: 0...99
            )
            .fixedSize()
        }
    }

    private func fetchAndAdd(barcode: String) {
        isLoading = true
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    appState.addProduct(product, toLocationWithID: locationID)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
