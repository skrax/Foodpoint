//
//  ScannerView.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

struct ScannerView: View {
    private enum UnitField: Hashable {
        case packageWeight, countLabel, countPerPackage
    }

    @Environment(AppState.self) private var appState
    @State private var isShowingScanner = false
    @State private var scannedProduct: FoodProduct?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @State private var isNewProduct = false
    @State private var unitMode: UnitTrackingMode = .count
    @State private var packageWeightText = ""
    @State private var countLabelText = "items"
    @State private var countPerPackageText = "1"
    @FocusState private var focusedUnitField: UnitField?

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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedUnitField = nil }
                }
            }
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

            Picker("Tracking", selection: $unitMode) {
                ForEach(UnitTrackingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField("Bag/package weight (g)", text: $packageWeightText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($focusedUnitField, equals: .packageWeight)

            if unitMode == .count {
                TextField("Count label (e.g. slices, bars)", text: $countLabelText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedUnitField, equals: .countLabel)

                TextField("Count per package (e.g. 15)", text: $countPerPackageText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .focused($focusedUnitField, equals: .countPerPackage)

                if let hint = derivedGramsPerUnitHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var derivedGramsPerUnitHint: String? {
        guard let weight = Double(packageWeightText), weight > 0,
              let count = Double(countPerPackageText), count > 0 else { return nil }
        let grams = (weight / count).formatted(.number.precision(.fractionLength(0...2)))
        let label = countLabelText.isEmpty ? "item" : countLabelText
        return "≈ \(grams) g per \(label)"
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
        ProductUnit.make(
            mode: unitMode,
            packageWeight: Double(packageWeightText),
            countLabel: countLabelText,
            countPerPackage: Double(countPerPackageText)
        )
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        didSave = false
        unitMode = .count
        packageWeightText = ""
        countLabelText = "items"
        countPerPackageText = "1"
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
