import Foundation
import Observation
import FoodFoundation

/// Pantry state: the flat list of saved food items and the remembered unit/
/// nutrition configuration per barcode. Owned by `FoodpointKit.AppState` as
/// its `pantry` property — construct a fresh `PantryStore()` in tests
/// rather than reaching through a shared singleton, since it's a single
/// mutable instance and tests may run in any order.
@Observable
public class PantryStore {
    public init() {}

    public var items: [FoodItem] = []
    /// Default unit config keyed by barcode. Kept separate from `items` so a
    /// product's configured label/package size survives it being fully
    /// consumed and removed, and is reused automatically on re-scan.
    public var unitConfigs: [String: ProductUnit] = [:]
    /// Additional remembered package-size variants per barcode (e.g. a "Small"
    /// 500g bag alongside the "Default" 750g one). Same `label`/`gramsPerUnit`
    /// as the barcode's `unitConfigs` entry — only `name` and
    /// `quantityPerPackage` (and, for count-mode units, the implied package
    /// weight) differ between variants, since a unit's tracking mode/label
    /// can't change per scan.
    public var unitVariants: [String: [ProductUnit]] = [:]
    /// Default nutrition data set per barcode — Open Food Facts' own figures
    /// if it had any, or the user's own once configured.
    public var nutritionConfigs: [String: NutritionVariant] = [:]
    /// Additional remembered nutrition variants per barcode (e.g. Open Food
    /// Facts' figures kept as an alternate once the user's custom values
    /// become the default, or vice versa).
    public var nutritionVariants: [String: [NutritionVariant]] = [:]

    /// Saves a scanned product, or adds another package of it if already saved.
    /// `unit` is used as-is for this add. If this barcode has no default
    /// config yet, `unit` also becomes that default. Likewise, if Open Food
    /// Facts provided usable nutrition data and none is remembered yet, it
    /// becomes the default nutrition variant.
    public func addProduct(_ product: Product, unit: ProductUnit) {
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
    public func allVariants(forBarcode barcode: String) -> [ProductUnit] {
        var list: [ProductUnit] = []
        if let base = unitConfigs[barcode] { list.append(base) }
        list.append(contentsOf: unitVariants[barcode] ?? [])
        return list
    }

    /// Remembers a new package-size variant for a barcode (carries its own
    /// `name`), so it can be picked again on a future scan instead of
    /// retyped from scratch.
    public func addUnitVariant(_ unit: ProductUnit, forBarcode barcode: String) {
        unitVariants[barcode, default: []].append(unit)
    }

    /// Updates an existing variant (matched by `id`) in place — the default
    /// slot or the variants list, whichever holds it — and refreshes any
    /// currently saved item whose `unit` is that same variant.
    public func updateVariant(_ variant: ProductUnit, forBarcode barcode: String) {
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
    public func removeVariant(_ variantID: UUID, forBarcode barcode: String) {
        guard unitConfigs[barcode]?.id != variantID else { return }
        unitVariants[barcode]?.removeAll { $0.id == variantID }
    }

    /// Makes a variant the default — swapping it into `unitConfigs` and
    /// moving the previous default into `unitVariants` in its place (so it
    /// remains selectable rather than disappearing). No-op if `variantID`
    /// is already the default, or isn't a known variant for this barcode.
    public func makeDefault(_ variantID: UUID, forBarcode barcode: String) {
        guard let currentDefault = unitConfigs[barcode], currentDefault.id != variantID,
              var list = unitVariants[barcode],
              let index = list.firstIndex(where: { $0.id == variantID }) else { return }
        let newDefault = list[index]
        list[index] = currentDefault
        unitVariants[barcode] = list
        unitConfigs[barcode] = newDefault
    }

    /// Renames the count label shared by all of a barcode's package-size
    /// variants (e.g. correcting "slice" to "bar"). The label is a
    /// barcode-wide property — every variant of a count-tracked product
    /// counts the same kind of unit — so this updates the default and every
    /// alternate at once, plus any saved item currently using one of them,
    /// rather than letting a single variant's edit drift out of sync with
    /// its siblings. No-op for weight-tracked units: their label is always
    /// "g", since `ProductUnit.trackingMode` infers `.weight` specifically
    /// from that label.
    public func renameUnitLabel(_ label: String, forBarcode barcode: String) {
        guard unitConfigs[barcode]?.trackingMode == .count else { return }
        unitConfigs[barcode]?.label = label
        if var list = unitVariants[barcode] {
            for index in list.indices {
                list[index].label = label
            }
            unitVariants[barcode] = list
        }
        if let index = items.firstIndex(where: { $0.id == barcode }), items[index].unit.trackingMode == .count {
            items[index].unit.label = label
        }
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
    public func allNutritionVariants(forBarcode barcode: String) -> [NutritionVariant] {
        var list: [NutritionVariant] = []
        if let base = nutritionConfigs[barcode] { list.append(base) }
        list.append(contentsOf: nutritionVariants[barcode] ?? [])
        return list
    }

    public func addNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
        nutritionVariants[barcode, default: []].append(variant)
    }

    public func updateNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
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
    public func removeNutritionVariant(_ variantID: UUID, forBarcode barcode: String) {
        guard nutritionConfigs[barcode]?.id != variantID else { return }
        nutritionVariants[barcode]?.removeAll { $0.id == variantID }
    }

    /// Makes an existing alternate variant the default, demoting the
    /// previous default into `nutritionVariants` in its place.
    public func makeNutritionDefault(_ variantID: UUID, forBarcode barcode: String) {
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
    public func setDefaultNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
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
    public func refreshNutritionVariant(_ variant: NutritionVariant, forBarcode barcode: String) {
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
    public func pendingNutritionUpdate(from offNutrition: Nutrition?, forBarcode barcode: String) -> NutritionVariant? {
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
    public func setQuantity(_ quantity: Double, forItemID itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }

    public func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }

    // MARK: - Meal-driven consumption (FoodpointKit orchestration, MK-3)
    //
    // `consume`/`restore` exist so `FoodpointKit.AppState` (the one place
    // allowed to know both `PantryKit` and `MealKit` exist, per
    // package-architecture.md §3.5) can apply a logged meal's pantry side
    // effects without duplicating any of `PantryStore`'s own mutation logic.
    // Neither method knows anything about `MealKit` — they take plain
    // `FoodFoundation` types, keeping this package's zero-`MealKit`-
    // dependency rule intact.

    /// Decrements the item matching `barcode` by `amount`, clamping to zero
    /// rather than going negative (meals-feature-design.md §4.4) — routed
    /// through `setQuantity`'s existing "quantity `<= 0` deletes the item"
    /// behavior rather than duplicating that logic here.
    ///
    /// Returns the amount actually consumed, which can be less than
    /// `amount` requested if there wasn't enough stock — the caller compares
    /// the two to detect the "insufficient stock, clamped" case and surface
    /// a soft inline note (meals-feature-design.md §4.4), rather than this
    /// method throwing or blocking. Returns `0` (no mutation) if `barcode`
    /// has no matching item, or `amount` isn't positive.
    @discardableResult
    public func consume(barcode: String, amount: Double) -> Double {
        guard amount > 0, let index = items.firstIndex(where: { $0.id == barcode }) else { return 0 }
        let available = items[index].quantity
        let consumedAmount = min(amount, available)
        setQuantity(available - consumedAmount, forItemID: barcode)
        return consumedAmount
    }

    /// Restores `amount` of `product` to the pantry — adding to an existing
    /// item if one still exists (matching `addProduct`'s "increment if
    /// present, else create" pattern, so this never duplicates an item that
    /// wasn't fully depleted), or fully re-creating one if `consume` had
    /// deleted it at zero (package-architecture.md §4.3's undo edge case:
    /// undoing a meal that fully depleted a pantry item must recreate it,
    /// not bump a quantity that no longer has anything to bump).
    ///
    /// `unit` is used only when creating a brand-new item, and only as a
    /// fallback: this barcode's own remembered `unitConfigs` entry is
    /// preferred when one exists, since it's the authoritative unit for this
    /// product (surviving even a full depletion) rather than whatever the
    /// caller happened to reconstruct — see
    /// `MealKit.LoggedIngredient.impliedUnit`, the caller's usual source for
    /// `unit`. Nutrition is likewise taken from `nutritionConfigs` when
    /// available, else `product.nutrition`, mirroring `addProduct`. A
    /// non-positive `amount` is a no-op.
    public func restore(product: Product, unit: ProductUnit, amount: Double) {
        guard amount > 0 else { return }
        if let index = items.firstIndex(where: { $0.id == product.id }) {
            items[index].quantity += amount
        } else {
            let resolvedUnit = unitConfigs[product.id] ?? unit
            var productToStore = product
            productToStore.nutrition = nutritionConfigs[product.id]?.nutrition ?? product.nutrition
            items.append(FoodItem(id: product.id, product: productToStore, quantity: amount, unit: resolvedUnit))
            if unitConfigs[product.id] == nil {
                unitConfigs[product.id] = resolvedUnit
            }
        }
    }
}
