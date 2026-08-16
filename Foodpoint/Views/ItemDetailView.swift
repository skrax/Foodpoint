import SwiftUI

/// Detail screen for one saved item: nutrition (per 100g, and per configured
/// unit if known), an editable quantity, and a "Package Sizes" button for
/// managing (renaming/resizing/adding/deleting) the barcode's variants.
/// Auto-dismisses if the item is removed (quantity driven to 0) while this
/// view is open.
struct ItemDetailView: View {
    let itemID: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isQuantityFocused: Bool

    @State private var quantityText = ""
    @State private var isShowingVariantManager = false

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

                    Button {
                        isShowingVariantManager = true
                    } label: {
                        Label("Package Sizes", systemImage: "shippingbox")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(item?.product.name ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isQuantityFocused = false }
            }
        }
        .onAppear {
            if let item { quantityText = formatted(item.quantity) }
        }
        .onChange(of: isQuantityFocused) { _, focused in
            if !focused, let value = Double(quantityText) {
                appState.setQuantity(value, forItemID: itemID)
            }
        }
        .onChange(of: item == nil) { _, isGone in
            if isGone { dismiss() }
        }
        .sheet(isPresented: $isShowingVariantManager) {
            PackageVariantsView(barcode: itemID, mode: .manage)
        }
    }

    /// Numeric quantity field (in `item.unit.label` units) plus ±1 nudge buttons.
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
                .focused($isQuantityFocused)

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

    /// `nil` when `gramsPerUnit` isn't configured — nothing to scale by.
    private func nutritionPerUnit(for item: FoodItem) -> Nutrition? {
        guard let nutrition = item.product.nutrition, let grams = item.unit.gramsPerUnit else { return nil }
        return nutrition.scaled(by: grams / 100)
    }

    /// E.g. "Nutrition per bar (40g)" followed by the scaled macro tiles.
    private func nutritionPerUnitSection(_ nutrition: Nutrition, label: String, grams: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition per \(label) (\(formatted(grams))g)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
            HStack {
                MetricView(label: "Calories", value: "\(Int(nutrition.energyKcal100g ?? 0)) kcal")
                MetricView(label: "Carbs", value: "\(String(format: "%.1f", nutrition.carbohydrates100g ?? 0))g")
                MetricView(label: "Protein", value: "\(String(format: "%.1f", nutrition.proteins100g ?? 0))g")
                MetricView(label: "Fat", value: "\(String(format: "%.1f", nutrition.fat100g ?? 0))g")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
