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

    /// Saves a scanned product, or adds another package of it if already saved.
    /// `unit` is used as-is for this add. If this barcode has no default
    /// config yet, `unit` also becomes that default.
    func addProduct(_ product: FoodProduct, unit: ProductUnit) {
        if unitConfigs[product.barcode] == nil {
            unitConfigs[product.barcode] = unit
        }

        if let index = items.firstIndex(where: { $0.id == product.barcode }) {
            items[index].quantity += unit.quantityPerPackage
        } else {
            items.append(FoodItem(id: product.barcode, product: product, quantity: unit.quantityPerPackage, unit: unit))
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
