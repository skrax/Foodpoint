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
    /// Additional remembered package-size variants per barcode (e.g. a 500g
    /// bag alongside the default 750g one). Same `label`/`gramsPerUnit` as
    /// the barcode's `unitConfigs` entry — only `quantityPerPackage` (and,
    /// for count-mode units, the implied package weight) differs between
    /// variants, since the unit's tracking mode/label can't change per scan.
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

    /// Remembers an alternate package-size variant for a barcode, so it can
    /// be picked again on a future scan instead of retyped from scratch.
    func addUnitVariant(_ unit: ProductUnit, forBarcode barcode: String) {
        unitVariants[barcode, default: []].append(unit)
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

    /// Updates a barcode's default unit config (label/quantity-per-package/
    /// grams-per-unit), both for future re-scans and on the currently saved
    /// item, if any. Does not affect any remembered `unitVariants`.
    func updateUnit(_ unit: ProductUnit, forItemID itemID: String) {
        unitConfigs[itemID] = unit
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].unit = unit
    }

    func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }
}
