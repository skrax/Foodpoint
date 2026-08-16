import Foundation
import Observation

/// App-wide state: the flat list of saved food items and the remembered
/// unit configuration per barcode. Single `@Observable` singleton injected
/// into the environment by `FoodpointApp`.
@Observable
class AppState {
    static let shared = AppState()

    private init() {}

    var items: [FoodItem] = []
    /// Default unit config keyed by barcode. Kept separate from `items` so a
    /// product's configured label/package size survives it being fully
    /// consumed and removed, and is reused automatically on re-scan.
    var unitConfigs: [String: ProductUnit] = [:]
    /// Additional remembered package-size variants per barcode (e.g. a "Small"
    /// 500g bag alongside the "Default" 750g one). Same `label`/`gramsPerUnit`
    /// as the barcode's `unitConfigs` entry — only `name` and
    /// `quantityPerPackage` (and, for count-mode units, the implied package
    /// weight) differ between variants, since a unit's tracking mode/label
    /// can't change per scan.
    var unitVariants: [String: [ProductUnit]] = [:]
    /// Default nutrition data set per barcode — Open Food Facts' own figures
    /// if it had any, or the user's own once configured.
    var nutritionConfigs: [String: NutritionVariant] = [:]
    /// Additional remembered nutrition variants per barcode (e.g. Open Food
    /// Facts' figures kept as an alternate once the user's custom values
    /// become the default, or vice versa).
    var nutritionVariants: [String: [NutritionVariant]] = [:]

    /// Saves a scanned product, or adds another package of it if already saved.
    /// `unit` is used as-is for this add. If this barcode has no default
    /// config yet, `unit` also becomes that default. Likewise, if Open Food
    /// Facts provided usable nutrition data and none is remembered yet, it
    /// becomes the default nutrition variant.
    func addProduct(_ product: Product, unit: ProductUnit) {
        if unitConfigs[product.id] == nil {
            unitConfigs[product.id] = unit
        }

        if nutritionConfigs[product.id] == nil, let nutrition = product.nutrition, !nutrition.isEffectivelyEmpty {
            nutritionConfigs[product.id] = NutritionVariant(name: NutritionSource.openFoodFacts.rawValue, nutrition: nutrition, source: .openFoodFacts)
        }

        var productToStore = product
        productToStore.nutrition = nutritionConfigs[product.id]?.nutrition

        if let index = items.firstIndex(where: { $0.id == product.id }) {
            items[index].quantity += unit.quantityPerPackage
        } else {
            items.append(FoodItem(id: product.id, product: productToStore, quantity: unit.quantityPerPackage, unit: unit))
        }
    }

    /// Every package-size variant known for a barcode: its default config
    /// first, then any remembered alternates.
    func allVariants(forBarcode barcode: String) -> [ProductUnit] {
        var list: [ProductUnit] = []
        if let base = unitConfigs[barcode] { list.append(base) }
        list.append(contentsOf: unitVariants[barcode] ?? [])
        return list
    }

    /// Remembers a new package-size variant for a barcode (carries its own
    /// `name`), so it can be picked again on a future scan instead of
    /// retyped from scratch.
    func addUnitVariant(_ unit: ProductUnit, forBarcode barcode: String) {
        unitVariants[barcode, default: []].append(unit)
    }

    /// Updates an existing variant (matched by `id`) in place — the default
    /// slot or the variants list, whichever holds it — and refreshes any
    /// currently saved item whose `unit` is that same variant.
    func updateVariant(_ variant: ProductUnit, forBarcode barcode: String) {
        if unitConfigs[barcode]?.id == variant.id {
            unitConfigs[barcode] = variant
        } else if var list = unitVariants[barcode], let index = list.firstIndex(where: { $0.id == variant.id }) {
            list[index] = variant
            unitVariants[barcode] = list
        }
        if let index = items.firstIndex(where: { $0.id == barcode }), items[index].unit.id == variant.id {
            items[index].unit = variant
        }
    }

    /// Removes a variant from `unitVariants`. The default (`unitConfigs`)
    /// entry is never removable this way — the UI hides that option for it.
    func removeVariant(_ variantID: UUID, forBarcode barcode: String) {
        guard unitConfigs[barcode]?.id != variantID else { return }
        unitVariants[barcode]?.removeAll { $0.id == variantID }
    }

    /// Makes a variant the default — swapping it into `unitConfigs` and
    /// moving the previous default into `unitVariants` in its place (so it
    /// remains selectable rather than disappearing). No-op if `variantID`
    /// is already the default, or isn't a known variant for this barcode.
    func makeDefault(_ variantID: UUID, forBarcode barcode: String) {
        guard let currentDefault = unitConfigs[barcode], currentDefault.id != variantID,
              var list = unitVariants[barcode],
              let index = list.firstIndex(where: { $0.id == variantID }) else { return }
        let newDefault = list[index]
        list[index] = currentDefault
        unitVariants[barcode] = list
        unitConfigs[barcode] = newDefault
    }

    // MARK: - Nutrition variants
    //
    // Mirrors the package-variant methods above exactly (allVariants ->
    // addUnitVariant -> updateVariant -> removeVariant -> makeDefault), plus
    // two additions specific to reconciling with Open Food Facts:
    // `setDefaultNutritionVariant` (used the first time a scan's data should
    // immediately replace the default, keeping the old one as an alternate)
    // and `refreshNutritionVariant` (upserts by id without touching which
    // variant is the default) and `pendingNutritionUpdate` (decides whether
    // there's anything new to tell the user about at all).

    /// Every nutrition variant known for a barcode: its default first, then
    /// any remembered alternates.
    func allNutritionVariants(forBarcode barcode: String) -> [NutritionVariant] {
        var list: [NutritionVariant] = []
        if let base = nutritionConfigs[barcode] { list.append(base) }
        list.append(contentsOf: nutritionVariants[barcode] ?? [])
        return list
    }

    func addNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
        nutritionVariants[barcode, default: []].append(variant)
    }

    func updateNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
        if nutritionConfigs[barcode]?.id == variant.id {
            nutritionConfigs[barcode] = variant
            syncItemNutrition(variant.nutrition, forBarcode: barcode)
        } else if var list = nutritionVariants[barcode], let index = list.firstIndex(where: { $0.id == variant.id }) {
            list[index] = variant
            nutritionVariants[barcode] = list
        }
    }

    /// Removes a variant from `nutritionVariants`. The default
    /// (`nutritionConfigs`) entry is never removable this way.
    func removeNutritionVariant(_ variantID: UUID, forBarcode barcode: String) {
        guard nutritionConfigs[barcode]?.id != variantID else { return }
        nutritionVariants[barcode]?.removeAll { $0.id == variantID }
    }

    /// Makes an existing alternate variant the default, demoting the
    /// previous default into `nutritionVariants` in its place.
    func makeNutritionDefault(_ variantID: UUID, forBarcode barcode: String) {
        guard let currentDefault = nutritionConfigs[barcode], currentDefault.id != variantID,
              var list = nutritionVariants[barcode],
              let index = list.firstIndex(where: { $0.id == variantID }) else { return }
        let newDefault = list[index]
        list[index] = currentDefault
        nutritionVariants[barcode] = list
        nutritionConfigs[barcode] = newDefault
        syncItemNutrition(newDefault.nutrition, forBarcode: barcode)
    }

    /// Sets `variant` as the default regardless of whether it was already
    /// known, preserving whatever was previously the default as an
    /// alternate. Used when the user picks "Use Open Food Facts" on a
    /// nutrition-update prompt, where the new variant may not have been
    /// stored as an alternate yet.
    func setDefaultNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
        nutritionVariants[barcode]?.removeAll { $0.id == variant.id }
        if let previousDefault = nutritionConfigs[barcode], previousDefault.id != variant.id {
            nutritionVariants[barcode, default: []].append(previousDefault)
        }
        nutritionConfigs[barcode] = variant
        syncItemNutrition(variant.nutrition, forBarcode: barcode)
    }

    /// Upserts `variant` by id (default slot or alternates list, whichever
    /// already holds it, or appended as a new alternate) without changing
    /// which variant is the default. Used when the user declines a
    /// nutrition update but Open Food Facts' new figures should still be
    /// remembered for future comparison.
    func refreshNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
        if nutritionConfigs[barcode]?.id == variant.id {
            nutritionConfigs[barcode] = variant
            syncItemNutrition(variant.nutrition, forBarcode: barcode)
        } else if var list = nutritionVariants[barcode], let index = list.firstIndex(where: { $0.id == variant.id }) {
            list[index] = variant
            nutritionVariants[barcode] = list
        } else {
            nutritionVariants[barcode, default: []].append(variant)
        }
    }

    /// The Open-Food-Facts-sourced variant to offer the user, or `nil` if
    /// there's nothing worth asking about: `offNutrition` is missing/empty,
    /// or it matches what's already remembered as this barcode's
    /// Open-Food-Facts-sourced variant (i.e. nothing changed since last time).
    func pendingNutritionUpdate(from offNutrition: Nutrition?, forBarcode barcode: String) -> NutritionVariant? {
        guard let offNutrition, !offNutrition.isEffectivelyEmpty else { return nil }
        let existingOFF = allNutritionVariants(forBarcode: barcode).first { $0.source == .openFoodFacts }
        if let existingOFF, existingOFF.nutrition.isApproximatelyEqual(to: offNutrition) {
            return nil
        }
        return NutritionVariant(
            id: existingOFF?.id ?? UUID(),
            name: existingOFF?.name ?? NutritionSource.openFoodFacts.rawValue,
            nutrition: offNutrition,
            source: .openFoodFacts
        )
    }

    private func syncItemNutrition(_ nutrition: Nutrition, forBarcode barcode: String) {
        guard let index = items.firstIndex(where: { $0.id == barcode }) else { return }
        items[index].product.nutrition = nutrition
    }

    /// Sets an item's remaining quantity. A value `<= 0` removes the item entirely.
    func setQuantity(_ quantity: Double, forItemID itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }

    func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }
}
