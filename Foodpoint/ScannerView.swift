//
//  ScannerView.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI
import OpenFoodFacts

/// "Scan" tab: scan a barcode, look up the product on Open Food Facts, and
/// either save it (into the flat item list, configuring its unit first if
/// this barcode has never been saved before) or discard it and scan again.
///
/// For a barcode that's already configured, the package-size fields are
/// still shown (pre-filled from the saved config) rather than a static
/// summary, so a different-sized package of the same product (e.g. a 500g
/// bag instead of the usual 750g) can be entered directly. The unit's
/// tracking mode and label can't change per scan — only the package weight,
/// with the count (if count-tracked) recomputed from it using the existing
/// grams-per-unit. If the edited size doesn't match any package size
/// already known for this barcode, saving asks whether to remember it as a
/// selectable variant for next time, or use it just this once.
struct ScannerView: View {
    private enum UnitField: Hashable {
        case packageWeight, countLabel, countPerPackage
    }

    @Environment(AppState.self) private var appState
    @State private var isShowingScanner = false
    @State private var scannedProduct: Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Whether the currently displayed `scannedProduct` has been saved yet.
    @State private var didSave = false
    /// Whether `scannedProduct`'s barcode has no remembered unit config yet,
    /// i.e. whether to show the fully-editable `unitConfigFields` (label,
    /// mode, and weight all free) instead of `knownUnitFields` (weight only).
    @State private var isNewProduct = false
    @State private var unitMode: UnitTrackingMode = .count
    @State private var packageWeightText = ""
    @State private var countLabelText = "items"
    @State private var countPerPackageText = "1"
    @FocusState private var focusedUnitField: UnitField?
    /// A package-size edit that doesn't match any variant already known for
    /// this barcode, awaiting the user's choice of whether to remember it.
    @State private var pendingUnit: ProductUnit?
    @State private var pendingVariantName = ""
    @State private var isShowingVariantPrompt = false
    @State private var isShowingVariantManager = false
    /// Open-Food-Facts-sourced nutrition data that's new or changed since
    /// last seen for this barcode, awaiting review. `nil` when there's
    /// nothing to ask about (see `AppState.pendingNutritionUpdate`).
    @State private var pendingNutritionUpdate: NutritionVariant?
    @State private var isShowingNutritionUpdate = false
    @State private var isShowingNutritionManager = false
    @State private var isShowingNutritionEntry = false

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
                    ProductDetailCard(
                        product: product,
                        nutritionOverride: appState.nutritionConfigs[product.id]?.nutrition,
                        nutritionSource: appState.nutritionConfigs[product.id]?.source
                    )
                    if didSave {
                        Text("Saved")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    } else if isNewProduct {
                        unitConfigFields
                    } else {
                        knownUnitFields(for: product)
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
            .alert(
                "New Package Size",
                isPresented: $isShowingVariantPrompt,
                presenting: pendingUnit
            ) { unit in
                TextField("Name (e.g. Small, Large)", text: $pendingVariantName)
                Button("Save Variant") { confirmSave(unit, storeVariant: true) }
                Button("Just This Once") { confirmSave(unit, storeVariant: false) }
                Button("Cancel", role: .cancel) { pendingUnit = nil; pendingVariantName = "" }
            } message: { unit in
                Text(variantPromptMessage(for: unit))
            }
            .sheet(isPresented: $isShowingVariantManager) {
                if let product = scannedProduct {
                    PackageVariantsView(barcode: product.id, mode: .select { variant in
                        selectKnownVariant(variant)
                    })
                }
            }
            .sheet(isPresented: $isShowingNutritionManager) {
                if let product = scannedProduct {
                    NutritionVariantsView(barcode: product.id)
                }
            }
            .sheet(isPresented: $isShowingNutritionEntry) {
                if let product = scannedProduct {
                    NutritionVariantEditForm(barcode: product.id, existing: nil)
                }
            }
            .sheet(isPresented: $isShowingNutritionUpdate) {
                if let product = scannedProduct, let update = pendingNutritionUpdate {
                    NutritionUpdateView(
                        barcode: product.id,
                        currentVariant: appState.nutritionConfigs[product.id],
                        updatedOFFVariant: update
                    ) {
                        pendingNutritionUpdate = nil
                    }
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

            newProductNutritionStatus
        }
        .padding(.horizontal)
    }

    /// For a brand-new barcode with no usable nutrition data yet — checked
    /// against whatever's already configured (`appState.nutritionConfigs`),
    /// not just this scan's raw Open Food Facts fetch, so the banner
    /// disappears immediately once custom values are added via the sheet
    /// below — offers a way to enter it manually. It becomes this barcode's
    /// default nutrition variant immediately (independent of tapping Save).
    @ViewBuilder
    private var newProductNutritionStatus: some View {
        let resolved = scannedProduct.flatMap { appState.nutritionConfigs[$0.id]?.nutrition } ?? scannedProduct?.nutrition
        if resolved == nil || (resolved?.isEffectivelyEmpty ?? true) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No nutrition data from Open Food Facts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    isShowingNutritionEntry = true
                } label: {
                    Label("Add Nutrition Values", systemImage: "plus.circle")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Live "≈ Xg per slice" preview computed from the weight/count fields,
    /// shown while the user is still filling in the count-mode form.
    private var derivedGramsPerUnitHint: String? {
        guard let weight = packageWeightText.localizedDouble, weight > 0,
              let count = countPerPackageText.localizedDouble, count > 0 else { return nil }
        let grams = (weight / count).formatted(.number.precision(.fractionLength(0...2)))
        let label = countLabelText.isEmpty ? "item" : countLabelText
        return "≈ \(grams) g per \(label)"
    }

    /// Package-size fields for an already-configured barcode: mode and label
    /// are shown but locked, only the weight is editable, and (for
    /// count-tracked units) the resulting count is derived and displayed
    /// read-only using the barcode's fixed grams-per-unit. A "Package Sizes"
    /// button opens `PackageVariantsView` to jump to, rename, or manage any
    /// remembered variant.
    private func knownUnitFields(for product: Product) -> some View {
        let base = appState.unitConfigs[product.id]
        return VStack(spacing: 8) {
            Text("Package size")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Tracking", selection: .constant(base?.trackingMode ?? .count)) {
                ForEach(UnitTrackingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(true)

            Button {
                isShowingVariantManager = true
            } label: {
                Label("Package Sizes", systemImage: "chevron.up.chevron.down")
                    .font(.caption)
            }

            TextField("Bag/package weight (g)", text: $packageWeightText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($focusedUnitField, equals: .packageWeight)

            if base?.trackingMode == .count {
                HStack {
                    Text("\(base?.label ?? "items"):")
                        .foregroundStyle(.secondary)
                    Text(derivedCountText(gramsPerUnit: base?.gramsPerUnit))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            knownProductNutritionStatus
        }
        .padding(.horizontal)
    }

    /// Either a "Review" button (Open Food Facts has new/changed data
    /// waiting) or a plain "Nutrition" button into `NutritionVariantsView`.
    private var knownProductNutritionStatus: some View {
        Group {
            if pendingNutritionUpdate != nil {
                Button {
                    isShowingNutritionUpdate = true
                } label: {
                    Label("Nutrition Data Available — Review", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption)
                }
            } else {
                Button {
                    isShowingNutritionManager = true
                } label: {
                    Label("Nutrition", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption)
                }
            }
        }
    }

    /// Count derived from `packageWeightText` using the barcode's fixed
    /// grams-per-unit — e.g. typing "500" with a 50g/slice ratio shows "10".
    private func derivedCountText(gramsPerUnit: Double?) -> String {
        guard let gramsPerUnit, gramsPerUnit > 0,
              let weight = packageWeightText.localizedDouble, weight > 0 else { return "—" }
        return (weight / gramsPerUnit).formatted(.number.precision(.fractionLength(0...2)))
    }

    private func selectKnownVariant(_ variant: ProductUnit) {
        packageWeightText = variant.packageWeight.map {
            $0.formatted(.number.precision(.fractionLength(0...2)))
        } ?? ""
    }

    private func variantDescription(_ variant: ProductUnit) -> String {
        let weight = (variant.packageWeight ?? variant.quantityPerPackage).formatted(.number.precision(.fractionLength(0...2)))
        switch variant.trackingMode {
        case .weight:
            return "\(weight) g"
        case .count:
            let count = variant.quantityPerPackage.formatted(.number.precision(.fractionLength(0...2)))
            return "\(weight) g (\(count) \(variant.label))"
        }
    }

    /// Builds the `ProductUnit` implied by the current weight field, reusing
    /// the barcode's fixed label/grams-per-unit — the parts of the unit that
    /// can't change per scan.
    private func candidateUnit(for product: Product) -> ProductUnit? {
        guard let base = appState.unitConfigs[product.id],
              let weight = packageWeightText.localizedDouble, weight > 0 else { return nil }
        switch base.trackingMode {
        case .weight:
            return ProductUnit(label: "g", quantityPerPackage: weight, gramsPerUnit: 1)
        case .count:
            guard let gramsPerUnit = base.gramsPerUnit, gramsPerUnit > 0 else { return base }
            return ProductUnit(label: base.label, quantityPerPackage: weight / gramsPerUnit, gramsPerUnit: gramsPerUnit)
        }
    }

    /// A known variant whose quantity matches `candidate`, if any — saving
    /// reuses it as-is rather than the freshly-typed (and float-rounded) value.
    private func matchingKnownVariant(_ candidate: ProductUnit, for barcode: String) -> ProductUnit? {
        appState.allVariants(forBarcode: barcode).first { abs($0.quantityPerPackage - candidate.quantityPerPackage) < 0.01 }
    }

    private func variantPromptMessage(for unit: ProductUnit) -> String {
        "\(variantDescription(unit)) isn't a saved package size yet. Remember it so you can pick it again on a future scan?"
    }

    /// Saves the current product, then immediately reopens the scanner for
    /// the next one. For a known barcode whose edited package size doesn't
    /// match anything already remembered, defers to `confirmSave` via the
    /// variant-prompt dialog instead of saving immediately.
    private func save() {
        guard let product = scannedProduct else { return }

        if isNewProduct {
            appState.addProduct(product, unit: unitFromFields())
            didSave = true
            scanAgain()
            return
        }

        guard let candidate = candidateUnit(for: product) else { return }
        if let matched = matchingKnownVariant(candidate, for: product.id) {
            appState.addProduct(product, unit: matched)
            didSave = true
            scanAgain()
        } else {
            pendingUnit = candidate
            isShowingVariantPrompt = true
        }
    }

    /// Completes a save that was held pending a variant-prompt decision.
    private func confirmSave(_ unit: ProductUnit, storeVariant: Bool) {
        guard let product = scannedProduct else { return }
        var finalUnit = unit
        if storeVariant {
            let trimmed = pendingVariantName.trimmingCharacters(in: .whitespacesAndNewlines)
            finalUnit.name = trimmed.isEmpty ? "Variant" : trimmed
            appState.addUnitVariant(finalUnit, forBarcode: product.id)
        }
        appState.addProduct(product, unit: finalUnit)
        didSave = true
        pendingUnit = nil
        pendingVariantName = ""
        scanAgain()
    }

    private func scanAgain() {
        errorMessage = nil
        isShowingScanner = true
    }

    /// Builds a `ProductUnit` from the new-product config form's current input.
    private func unitFromFields() -> ProductUnit {
        ProductUnit.make(
            mode: unitMode,
            packageWeight: packageWeightText.localizedDouble,
            countLabel: countLabelText,
            countPerPackage: countPerPackageText.localizedDouble
        )
    }

    private func fetchFoodData(for barcode: String) {
        isLoading = true
        didSave = false
        pendingUnit = nil
        pendingVariantName = ""
        pendingNutritionUpdate = nil
        unitMode = .count
        packageWeightText = ""
        countLabelText = "items"
        countPerPackageText = "1"
        Task {
            do {
                let offProduct = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                let product = Product(offProduct: offProduct)
                await MainActor.run {
                    self.scannedProduct = product
                    self.isLoading = false
                    if let base = appState.unitConfigs[barcode] {
                        self.isNewProduct = false
                        self.packageWeightText = base.packageWeight.map {
                            $0.formatted(.number.precision(.fractionLength(0...2)))
                        } ?? ""
                        self.pendingNutritionUpdate = appState.pendingNutritionUpdate(from: product.nutrition, forBarcode: barcode)
                    } else {
                        self.isNewProduct = true
                    }
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
