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
    @State private var didSave = false

    private var canSave: Bool {
        scannedProduct != nil && !didSave && !isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Fetching product details...")
                        .padding()
                } else if let product = scannedProduct {
                    ProductDetailCard(product: product)
                    if didSave {
                        Text("Saved")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                } else if let error = errorMessage {
                    ContentUnavailableView("Scan Failed", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView("No Product Scanned", systemImage: "barcode.viewfinder", description: Text("Tap the button below to scan a food package."))
                }

                Button {
                    primaryAction()
                } label: {
                    Label(
                        canSave ? "Save" : "Scan Food Barcode",
                        systemImage: canSave ? "checkmark.circle" : "barcode.viewfinder"
                    )
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(isLoading)
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

    private func primaryAction() {
        if canSave, let product = scannedProduct {
            appState.addProduct(product)
            didSave = true
        }
        errorMessage = nil
        isShowingScanner = true
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        didSave = false
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
