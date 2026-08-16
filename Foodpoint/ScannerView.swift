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
    @State private var isNewProduct = false
    @State private var unitLabel = "items"
    @State private var quantityPerPackageText = "1"
    @State private var gramsPerUnitText = ""

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
                    } else if isNewProduct {
                        unitConfigFields
                    }
                } else if let error = errorMessage {
                    ContentUnavailableView("Scan Failed", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView("No Product Scanned", systemImage: "barcode.viewfinder", description: Text("Tap the button below to scan a food package."))
                }

                if canSave {
                    Button {
                        save()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Button {
                        scanAgain()
                    } label: {
                        Label("Scan Without Saving", systemImage: "barcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else {
                    Button {
                        scanAgain()
                    } label: {
                        Label("Scan Food Barcode", systemImage: "barcode.viewfinder")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .disabled(isLoading)
                }
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

    private var unitConfigFields: some View {
        VStack(spacing: 8) {
            Text("How is this counted?")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Count label (e.g. bars, slices, g)", text: $unitLabel)
                .textFieldStyle(.roundedBorder)

            TextField("Quantity per package", text: $quantityPerPackageText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)

            TextField("Grams per unit (optional)", text: $gramsPerUnitText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
        }
        .padding(.horizontal)
    }

    private func save() {
        guard let product = scannedProduct else { return }
        let unit = isNewProduct ? unitFromFields() : nil
        appState.addProduct(product, unit: unit)
        didSave = true
        scanAgain()
    }

    private func scanAgain() {
        errorMessage = nil
        isShowingScanner = true
    }

    private func unitFromFields() -> ProductUnit {
        let label = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityPerPackage = Double(quantityPerPackageText) ?? 1
        let gramsPerUnit = Double(gramsPerUnitText)
        return ProductUnit(
            label: label.isEmpty ? "items" : label,
            quantityPerPackage: quantityPerPackage > 0 ? quantityPerPackage : 1,
            gramsPerUnit: gramsPerUnit
        )
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        didSave = false
        unitLabel = "items"
        quantityPerPackageText = "1"
        gramsPerUnitText = ""
        Task {
            do {
                let product = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.scannedProduct = product
                    self.isLoading = false
                    self.isNewProduct = appState.unitConfigs[barcode] == nil
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
