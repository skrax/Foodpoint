import SwiftUI

struct MainContentView: View {
    @State private var isShowingScanner = false
    @State private var scannedProduct: FoodProduct?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Fetching product details...")
                        .padding()
                } else if let product = scannedProduct {
                    ProductDetailCard(product: product)
                } else if let error = errorMessage {
                    ContentUnavailableView("Scan Failed", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView("No Product Scanned", systemImage: "barcode.viewfinder", description: Text("Tap the button below to scan a food package."))
                }

                Button {
                    errorMessage = nil
                    isShowingScanner = true
                } label: {
                    Label("Scan Food Barcode", systemImage: "barcode.viewfinder")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .navigationTitle("Food Tracker")
            .sheet(isPresented: $isShowingScanner) {
                ZStack {
                    FastFoodBarcodeScanner { barcode in
                        isShowingScanner = false
                        fetchFoodData(for: barcode)
                    }
                    .ignoresSafeArea()

                    ViewfinderOverlay()
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.scannedProduct = product
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// A simple UI Card to present the parsed Open Food Facts details
struct ProductDetailCard: View {
    let product: FoodProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                if let imageUrl = product.imageFrontUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName ?? "Unknown Product")
                        .font(.title3)
                        .bold()
                    
                    Text(product.brands ?? "Unknown Brand")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let score = product.nutriScoreGrade?.uppercased() {
                        Text("Nutri-Score: \(score)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            Divider()

            if let nutriments = product.nutriments {
                Text("Nutrition Facts (per 100g)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                HStack {
                    MetricView(label: "Calories", value: "\(Int(nutriments.energyKcal100g ?? 0)) kcal")
                    MetricView(label: "Carbs", value: "\(String(format: "%.1f", nutriments.carbohydrates100g ?? 0))g")
                    MetricView(label: "Protein", value: "\(String(format: "%.1f", nutriments.proteins100g ?? 0))g")
                    MetricView(label: "Fat", value: "\(String(format: "%.1f", nutriments.fat100g ?? 0))g")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }
}

struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.footnote).bold()
        }
        .frame(maxWidth: .infinity)
    }
}
