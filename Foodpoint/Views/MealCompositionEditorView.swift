import SwiftUI
import FoodpointKit

/// Builds a meal from ingredient rows, one per acquired product, plus a
/// running nutrition footer with an explicit completeness signal
/// (meals-feature-design.md §6/§8.2). This is the reusable composition
/// editor MK-2 delivers; `MealsView` (MK-3) wires its `onDone` callback into
/// a real "Save"/"Log" action — `appState.meals.plan` followed immediately
/// by `appState.markMealEaten(_:)` — that creates the entry and triggers
/// pantry orchestration (package-architecture.md §3.5). This view itself
/// still never touches `appState.meals.entries` or `appState.pantry`'s
/// quantities directly, only reads from them for the acquisition sources
/// below — the actual persisting/orchestrating stays the caller's job.
/// MK-4/MK-5 are expected to reuse this same view for template creation and
/// planning, which is why `onDone` hands back the composed ingredients
/// rather than this view persisting anything itself.
///
/// Four ingredient sources (§6.1), each ultimately producing one more row:
/// 1. **From the pantry** (`MealIngredientPantryPickerView`) — reads
///    `appState.pantry.items` directly, since this is the one source
///    `MealKit` can't provide on its own; reuses the pantry's own
///    already-configured `ProductUnit` for that barcode, no unit setup asked.
/// 2. **From history** (`MealIngredientHistoryPickerView`) — reads
///    `appState.meals.recentlyUsedIngredients()`, no network call.
/// 3. **Scan** — `FastFoodBarcodeScanner`, then `ProductLookup.fetch(barcode:)`.
/// 4. **Search** — `ProductSearchView`, then the same `ProductLookup.fetch(barcode:)`
///    re-resolution `ScannerView` already uses for a search pick, so there's
///    one downstream code path (`beginAcquisition`), not two.
///
/// Scan/search may return a barcode this store has never used as an
/// ingredient before (`appState.meals.lastKnownUnit(forBarcode:) == nil`) —
/// those get `MealIngredientUnitSetupView`'s minimal weight/count + label
/// prompt, scoped to this ingredient only (§6.3), before a row is added.
struct MealCompositionEditorView: View {
    /// Called with the composed ingredient list when "Done" is tapped —
    /// empty if nothing was added. Not called on "Cancel". Defaults to a
    /// no-op so this view is still usable stand-alone (e.g. previews) even
    /// though `MealsView` (MK-3) now supplies a real handler.
    var onDone: ([LoggedIngredient]) -> Void = { _ in }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ComposerRow] = []

    @State private var isShowingSourceMenu = false
    @State private var isShowingPantryPicker = false
    @State private var isShowingHistoryPicker = false
    @State private var isShowingScanner = false
    @State private var isShowingSearch = false

    @State private var isAcquiring = false
    @State private var acquisitionErrorMessage: String?
    @State private var isShowingAcquisitionError = false
    /// A freshly-fetched product with no known unit yet, awaiting the
    /// minimal unit-setup prompt (§6.3) before it can become a row.
    @State private var pendingUnitSetupProduct: Product?

    /// One ingredient row's editable state: the current `LoggedIngredient`
    /// snapshot plus the raw text of its amount field, kept separate so an
    /// in-progress edit (e.g. "1." before the next digit) doesn't get
    /// clobbered by re-parsing on every keystroke.
    private struct ComposerRow: Identifiable {
        var ingredient: LoggedIngredient
        var amountText: String
        var id: UUID { ingredient.id }
    }

    private var completeness: NutritionCompleteness {
        MealStore.completeness(for: rows.map(\.ingredient))
    }

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty && !isAcquiring {
                    ContentUnavailableView(
                        "No Ingredients Yet",
                        systemImage: "carrot",
                        description: Text("Add ingredients from your pantry, your history, or by scanning or searching for a product.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(rows) { row in
                                ingredientRow(row)
                            }
                            .onDelete { offsets in
                                rows.remove(atOffsets: offsets)
                            }
                        }
                        if isAcquiring {
                            HStack {
                                Spacer()
                                ProgressView("Fetching product...")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !rows.isEmpty {
                    footer
                }
            }
            .navigationTitle("New Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(rows.map(\.ingredient))
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu {
                        Button {
                            isShowingPantryPicker = true
                        } label: {
                            Label("From Pantry", systemImage: "shippingbox")
                        }
                        Button {
                            isShowingHistoryPicker = true
                        } label: {
                            Label("From History", systemImage: "clock.arrow.circlepath")
                        }
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button {
                            isShowingSearch = true
                        } label: {
                            Label("Search by Name", systemImage: "magnifyingglass")
                        }
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                    Spacer()
                }
            }
            .sheet(isPresented: $isShowingPantryPicker) {
                MealIngredientPantryPickerView { item in
                    addFromPantry(item)
                }
            }
            .sheet(isPresented: $isShowingHistoryPicker) {
                MealIngredientHistoryPickerView { ingredient in
                    addFromHistory(ingredient)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                ZStack {
                    FastFoodBarcodeScanner { barcode in
                        isShowingScanner = false
                        beginAcquisition(barcode: barcode)
                    }
                    .ignoresSafeArea()

                    ViewfinderOverlay()
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $isShowingSearch) {
                ProductSearchView { barcode in
                    isShowingSearch = false
                    beginAcquisition(barcode: barcode)
                }
            }
            .sheet(item: $pendingUnitSetupProduct) { product in
                MealIngredientUnitSetupView(product: product) { unit in
                    appendRow(product: product, unit: unit)
                }
            }
            .alert("Couldn't Add Ingredient", isPresented: $isShowingAcquisitionError, presenting: acquisitionErrorMessage) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Row UI

    private func ingredientRow(_ row: ComposerRow) -> some View {
        let ingredient = row.ingredient
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let url = ingredient.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading) {
                    Text(ingredient.productName ?? "Unknown Product")
                        .font(.headline)
                    if let brand = ingredient.productBrand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            HStack {
                TextField("Amount", text: amountTextBinding(for: row.id))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                Text(ingredient.unitLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                if let nutrition = ingredient.nutritionSnapshot, let kcal = nutrition.energyKcal100g {
                    Text("\(kcal.formatted(.number.precision(.fractionLength(0...0)))) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No nutrition data")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Toggle("Use from pantry", isOn: usesFromPantryBinding(for: row.id))
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                MetricView(label: "Calories", value: caloriesText)
                MetricView(label: "Protein", value: macroText(completeness.total.proteins100g))
                MetricView(label: "Carbs", value: macroText(completeness.total.carbohydrates100g))
                MetricView(label: "Fat", value: macroText(completeness.total.fat100g))
            }
            if !completeness.isComplete {
                Label(
                    "\(completeness.missingCount) of \(completeness.consideredCount) ingredient\(completeness.consideredCount == 1 ? "" : "s") missing nutrition data",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    /// "≥ 340 kcal" when incomplete (meals-feature-design.md §8.2's honesty
    /// principle — the true total could be higher, never shown as if exact),
    /// or a plain figure once every considered ingredient has real data.
    private var caloriesText: String {
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return completeness.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    private func macroText(_ grams: Double?) -> String {
        "\((grams ?? 0).formatted(.number.precision(.fractionLength(0...1))))g"
    }

    // MARK: - Row bindings

    private func amountTextBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { rows.first(where: { $0.id == id })?.amountText ?? "" },
            set: { updateAmount(for: id, text: $0) }
        )
    }

    private func usesFromPantryBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { rows.first(where: { $0.id == id })?.ingredient.usesFromPantry ?? true },
            set: { newValue in
                guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
                rows[index].ingredient.usesFromPantry = newValue
            }
        )
    }

    /// Re-derives the row's `LoggedIngredient` for a newly-typed amount via
    /// `MealStore.makeIngredient`, using the ingredient's own
    /// `impliedUnit`/`impliedNutritionPer100g` to recompute grams/nutrition
    /// without any network call — the same trick that makes the "from
    /// history" source (§6.1 #2) work without one. Leaves the row's
    /// (possibly-invalid, still-being-typed) `amountText` alone regardless
    /// of whether it currently parses.
    private func updateAmount(for id: UUID, text: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].amountText = text
        guard let amount = text.localizedDouble else { return }
        let current = rows[index].ingredient
        rows[index].ingredient = MealStore.makeIngredient(
            barcode: current.barcode,
            productName: current.productName,
            productBrand: current.productBrand,
            imageURL: current.imageURL,
            nutritionPer100g: current.impliedNutritionPer100g,
            amount: amount,
            unit: current.impliedUnit,
            nutritionSource: current.nutritionSource ?? .openFoodFacts,
            usesFromPantry: current.usesFromPantry
        )
    }

    // MARK: - Acquisition

    /// Source #1: pantry pick. The pantry already knows this barcode's
    /// `ProductUnit`, so there's no unit setup to ask about — the row
    /// starts at amount `1` in that unit, ready to be adjusted.
    ///
    /// This is the one ingredient source that can produce a `.custom`
    /// `nutritionSource` (meals-feature-design.md §8.3): `MealKit` itself
    /// has no notion of "custom" nutrition, since it never depends on
    /// `PantryKit`, so the barcode's currently-default variant source is
    /// read here, at the app layer, and passed through explicitly —
    /// `appState.pantry.nutritionConfigs` is exactly the same lookup
    /// `ItemDetailView`/`ProductDetailCard` already use for their own source
    /// badge.
    private func addFromPantry(_ item: FoodItem) {
        let ingredient = MealStore.makeIngredient(
            barcode: item.product.id,
            productName: item.product.name,
            productBrand: item.product.brand,
            imageURL: item.product.imageURL,
            nutritionPer100g: item.product.nutrition,
            amount: 1,
            unit: item.unit,
            nutritionSource: appState.pantry.nutritionConfigs[item.product.id]?.source ?? .openFoodFacts
        )
        rows.append(ComposerRow(ingredient: ingredient, amountText: "1"))
    }

    /// Source #2: history pick. Reuses the historical ingredient's amount
    /// and (frozen) fields — including its `nutritionSource` — as-is for the
    /// new row's starting point; a fresh `id` keeps it independent from the
    /// historical record it was copied from.
    private func addFromHistory(_ historical: LoggedIngredient) {
        let ingredient = LoggedIngredient(
            barcode: historical.barcode,
            productName: historical.productName,
            productBrand: historical.productBrand,
            imageURL: historical.imageURL,
            amount: historical.amount,
            unitLabel: historical.unitLabel,
            gramsResolved: historical.gramsResolved,
            nutritionSnapshot: historical.nutritionSnapshot,
            nutritionSource: historical.nutritionSource,
            usesFromPantry: true
        )
        rows.append(ComposerRow(ingredient: ingredient, amountText: formattedAmount(historical.amount)))
    }

    /// Sources #3/#4 (scan/search) funnel through here once a barcode is in
    /// hand: fetch the product, then either add a row immediately (this
    /// barcode has a known unit already, from `appState.meals`' own
    /// history) or stash the product and prompt the minimal unit setup
    /// first (§6.3) — never reaching into `appState.pantry` for a unit,
    /// even if this barcode happens to be configured there too.
    private func beginAcquisition(barcode: String) {
        isAcquiring = true
        Task {
            do {
                let product = try await ProductLookup.fetch(barcode: barcode)
                await MainActor.run {
                    isAcquiring = false
                    if let unit = appState.meals.lastKnownUnit(forBarcode: barcode) {
                        appendRow(product: product, unit: unit)
                    } else {
                        pendingUnitSetupProduct = product
                    }
                }
            } catch {
                await MainActor.run {
                    isAcquiring = false
                    acquisitionErrorMessage = error.localizedDescription
                    isShowingAcquisitionError = true
                }
            }
        }
    }

    private func appendRow(product: Product, unit: ProductUnit) {
        let ingredient = MealStore.makeIngredient(
            barcode: product.id,
            productName: product.name,
            productBrand: product.brand,
            imageURL: product.imageURL,
            nutritionPer100g: product.nutrition,
            amount: 1,
            unit: unit
        )
        rows.append(ComposerRow(ingredient: ingredient, amountText: "1"))
    }

    private func formattedAmount(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}
