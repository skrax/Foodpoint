import SwiftUI

struct ItemDetailView: View {
    private enum Field: Hashable {
        case quantity, packageWeight, countLabel, countPerPackage
    }

    let itemID: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var quantityText = ""
    @State private var isEditingUnit = false
    @State private var unitMode: UnitTrackingMode = .count
    @State private var packageWeightText = ""
    @State private var countLabelText = ""
    @State private var countPerPackageText = ""

    private var item: FoodItem? {
        appState.items.first { $0.id == itemID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let item {
                    ProductDetailCard(product: item.product)

                    if let grams = item.unit.gramsPerUnit, let perUnit = nutritionPerUnit(for: item) {
                        nutritionPerUnitSection(perUnit, label: item.unit.label, grams: grams)
                    }

                    quantitySection(for: item)
                    unitEditSection(for: item)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(item?.product.productName ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            if let item { quantityText = formatted(item.quantity) }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .quantity, newValue != .quantity, let value = Double(quantityText) {
                appState.setQuantity(value, forItemID: itemID)
            }
        }
        .onChange(of: item == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }

    private func quantitySection(for item: FoodItem) -> some View {
        HStack {
            Button {
                adjust(by: -1, item: item)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title2)
            }

            TextField("Quantity", text: $quantityText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .quantity)

            Button {
                adjust(by: 1, item: item)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title2)
            }

            Text(item.unit.label)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func adjust(by delta: Double, item: FoodItem) {
        let newValue = max(0, item.quantity + delta)
        appState.setQuantity(newValue, forItemID: itemID)
        quantityText = formatted(newValue)
    }

    private func nutritionPerUnit(for item: FoodItem) -> Nutriments? {
        guard let nutriments = item.product.nutriments, let grams = item.unit.gramsPerUnit else { return nil }
        return nutriments.scaled(by: grams / 100)
    }

    private func nutritionPerUnitSection(_ nutriments: Nutriments, label: String, grams: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition per \(label) (\(formatted(grams))g)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
            HStack {
                MetricView(label: "Calories", value: "\(Int(nutriments.energyKcal100g ?? 0)) kcal")
                MetricView(label: "Carbs", value: "\(String(format: "%.1f", nutriments.carbohydrates100g ?? 0))g")
                MetricView(label: "Protein", value: "\(String(format: "%.1f", nutriments.proteins100g ?? 0))g")
                MetricView(label: "Fat", value: "\(String(format: "%.1f", nutriments.fat100g ?? 0))g")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func unitEditSection(for item: FoodItem) -> some View {
        VStack(spacing: 8) {
            if isEditingUnit {
                Picker("Tracking", selection: $unitMode) {
                    ForEach(UnitTrackingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Bag/package weight (g)", text: $packageWeightText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .packageWeight)

                if unitMode == .count {
                    TextField("Count label (e.g. slices, bars)", text: $countLabelText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .countLabel)

                    TextField("Count per package (e.g. 15)", text: $countPerPackageText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .countPerPackage)

                    if let hint = derivedGramsPerUnitHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Save Unit") {
                    saveUnit()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Edit Unit") {
                    beginEditingUnit(item.unit)
                }
                .buttonStyle(.bordered)
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

    private func beginEditingUnit(_ unit: ProductUnit) {
        unitMode = unit.trackingMode
        packageWeightText = unit.packageWeight.map(formatted) ?? ""
        switch unit.trackingMode {
        case .weight:
            countLabelText = ""
            countPerPackageText = ""
        case .count:
            countLabelText = unit.label
            countPerPackageText = formatted(unit.quantityPerPackage)
        }
        isEditingUnit = true
    }

    private func saveUnit() {
        let unit = ProductUnit.make(
            mode: unitMode,
            packageWeight: Double(packageWeightText),
            countLabel: countLabelText,
            countPerPackage: Double(countPerPackageText)
        )
        appState.updateUnit(unit, forItemID: itemID)
        isEditingUnit = false
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
