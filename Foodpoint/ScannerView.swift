//
//  ScannerView.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

struct ScannerView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingScanner = false
    @State private var scannedProduct: FoodProduct?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedLocationName: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Fetching product details...")
                        .padding()
                } else if let product = scannedProduct {
                    ProductDetailCard(product: product)
                    saveToLocationSection(for: product)
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

    @ViewBuilder
    private func saveToLocationSection(for product: FoodProduct) -> some View {
        if appState.locations.isEmpty {
            Text("Create a location to save this product.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(appState.locations) { location in
                    Button(location.name) {
                        appState.addProduct(product, toLocationWithID: location.id)
                        savedLocationName = location.name
                    }
                }
            } label: {
                Label("Save to Location", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.bordered)

            if let savedLocationName {
                Text("Saved to \(savedLocationName)")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        savedLocationName = nil
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