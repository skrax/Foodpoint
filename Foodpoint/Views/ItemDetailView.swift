import SwiftUI
import FoodpointKit

/// Detail screen for one saved item: nutrition (per 100g, and per configured
/// unit if known), an editable quantity, and a "Package Sizes" button for
/// managing (renaming/resizing/adding/deleting) the barcode's variants.
/// Auto-dismisses if the item is removed (quantity driven to 0) while this
/// view is open.
///
/// **Consumption section (MK-6, meals-feature-design.md §9):** last eaten,
/// times eaten, and total amount over the last 30 days, read from
/// `appState.meals.consumptionStats(barcode:from:to:)` keyed by this item's
/// barcode (`itemID`). This is the one place `ItemDetailView` — a `PantryKit`
/// view — reaches into `appState.meals`; `MealKit` itself never reaches back
/// into `PantryKit`, so this cross-referencing-by-barcode happens here, in
/// glue code, exactly like the "from pantry" ingredient source does in the
/// other direction (package-architecture.md §3.5).
struct ItemDetailView: View {
    let itemID: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isQuantityFocused: Bool

    @State private var quantityText = ""
    @State private var isShowingVariantManager = false
    @State private var isShowingNutritionManager = false

    private var item: FoodItem? {
        appState.pantry.items.first { $0.id == itemID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let item {
                    ProductDetailCard(product: item.product, nutritionSource: appState.pantry.nutritionConfigs[item.id]?.source)

                    if let grams = item.unit.gramsPerUnit, let perUnit = nutritionPerUnit(for: item) {
                        nutritionPerUnitSection(perUnit, label: item.unit.label, grams: grams)
                    }

                    quantitySection(for: item)

                    consumptionSection(for: item)

                    HStack {
                        Button {
                            isShowingVariantManager = true
                        } label: {
                            Label("Package Sizes", systemImage: "shippingbox")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isShowingNutritionManager = true
                        } label: {
                            Label("Nutrition", systemImage: "chart.bar.doc.horizontal")
                        }
                        .buttonStyle(.bordered)
                    }
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
            if !focused, let value = quantityText.localizedDouble {
                appState.pantry.setQuantity(value, forItemID: itemID)
            }
        }
        .onChange(of: item == nil) { _, isGone in
            if isGone { dismiss() }
        }
        .sheet(isPresented: $isShowingVariantManager) {
            PackageVariantsView(barcode: itemID, mode: .manage)
        }
        .sheet(isPresented: $isShowingNutritionManager) {
            NutritionVariantsView(barcode: itemID)
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

    /// Consumption stats for this item's barcode over the trailing 30 days
    /// (meals-feature-design.md §9) — counts every logged `.eaten` ingredient
    /// row regardless of that entry's "Use from pantry" toggle, since "did I
    /// eat this" is a different question from "did it come out of my shelf."
    private func consumptionStats(for item: FoodItem) -> ConsumptionStats {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: end)) ?? end
        return appState.meals.consumptionStats(barcode: item.id, from: start, to: end)
    }

    /// The unit label `MealKit`'s own logged ingredients for this barcode
    /// actually used, most-recent first, since `ConsumptionStats.totalAmount`
    /// is summed in whatever unit each meal-log row was logged in — which
    /// isn't guaranteed to match this item's *current* pantry unit (the two
    /// are independently configured, per meals-feature-design.md §6.3).
    /// Falls back to the pantry's own unit label if this barcode has never
    /// been logged as a meal ingredient, purely so the tile always shows
    /// some label rather than none.
    private func consumptionUnitLabel(for item: FoodItem) -> String {
        appState.meals.recentlyUsedIngredients().first { $0.barcode == item.id }?.unitLabel ?? item.unit.label
    }

    /// "Consumption" section: last eaten, times eaten, and total amount over
    /// the last 30 days. Shows a plain "not eaten" note rather than zeroed
    /// tiles when nothing was logged, so an unused product doesn't look like
    /// a data gap.
    private func consumptionSection(for item: FoodItem) -> some View {
        let stats = consumptionStats(for: item)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Consumption (Last 30 Days)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)

            if stats.timesEaten == 0 {
                Text("Not eaten in the last 30 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    MetricView(label: "Times Eaten", value: "\(stats.timesEaten)")
                    MetricView(label: "Total Amount", value: "\(formatted(stats.totalAmount)) \(consumptionUnitLabel(for: item))")
                    MetricView(label: "Last Eaten", value: stats.lastEatenDate.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func adjust(by delta: Double, item: FoodItem) {
        let newValue = max(0, item.quantity + delta)
        appState.pantry.setQuantity(newValue, forItemID: itemID)
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
