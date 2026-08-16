//
//  ScannerView.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

/// "Scan" tab: scan a barcode, look up the product on Open Food Facts, and
/// either save it (into the flat item list, configuring its unit first if
/// this barcode has never been saved before) or discard it and scan again.
struct ScannerView: View {
    private enum UnitField: Hashable {
        case packageWeight, countLabel, countPerPackage
    }

    @Environment(AppState.self) private var appState
    @State private var isShowingScanner = false
    @State private var scannedProduct: FoodProduct?
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Whether the currently displayed `scannedProduct` has been saved yet.
    @State private var didSave = false
    /// Whether `scannedProduct`'s barcode has no remembered unit config yet,
    /// i.e. whether to show `unitConfigFields` before it can be saved.
    @State private var isNewProduct = false
    @State private var unitMode: UnitTrackingMode = .count
    @State private var packageWeightText = ""
    @State private var countLabelText = "items"
    @State private var countPerPackageText = "1"
    @FocusState private var focusedUnitField: UnitField?

    /// Whether the "Save" / "Scan Without Saving" pair should replace the
    /// plain "Scan Food Barcode" button.
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

    /// Weight/Count tracking-mode setup shown only for a barcode that's
    /// never been saved before; reused every time this barcode is saved
    /// afterwards without being shown again.
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

    /// Live "≈ Xg per slice" preview computed from the weight/count fields,
    /// shown while the user is still filling in the count-mode form.
    private var derivedGramsPerUnitHint: String? {
        guard let weight = Double(packageWeightText), weight > 0,
              let count = Double(countPerPackageText), count > 0 else { return nil }
        let grams = (weight / count).formatted(.number.precision(.fractionLength(0...2)))
        let label = countLabelText.isEmpty ? "item" : countLabelText
        return "≈ \(grams) g per \(label)"
    }

    /// Saves the current product, then immediately reopens the scanner for the next one.
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

    /// Builds a `ProductUnit` from the config form's current input.
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
