import Observation

/// App-wide state: the flat list of saved food items and the remembered
/// unit configuration per barcode. Single `@Observable` singleton injected
/// into the environment by `FoodpointApp`.
@Observable
class AppState {
    static let shared = AppState()

    private init() {}

    var items: [FoodItem] = []
    /// Unit config keyed by barcode. Kept separate from `items` so a
    /// product's configured label/package size survives it being fully
    /// consumed and removed, and is reused automatically on re-scan.
    var unitConfigs: [String: ProductUnit] = [:]

    /// Saves a scanned product, or adds another package of it if already saved.
    /// - Parameter unit: The unit config to use for a brand-new barcode
    ///   (from the scanner's setup form). Ignored if this barcode already
    ///   has a remembered config — that one wins. Falls back to `.items`
    ///   if neither is available.
    func addProduct(_ product: FoodProduct, unit: ProductUnit? = nil) {
        let resolvedUnit = unitConfigs[product.barcode] ?? unit ?? .items
        unitConfigs[product.barcode] = resolvedUnit

        if let index = items.firstIndex(where: { $0.id == product.barcode }) {
            items[index].quantity += resolvedUnit.quantityPerPackage
        } else {
            items.append(FoodItem(id: product.barcode, product: product, quantity: resolvedUnit.quantityPerPackage, unit: resolvedUnit))
        }
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

    /// Updates a barcode's unit config (label/quantity-per-package/grams-per-unit),
    /// both for future re-scans and on the currently saved item, if any.
    func updateUnit(_ unit: ProductUnit, forItemID itemID: String) {
        unitConfigs[itemID] = unit
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].unit = unit
    }

    func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }
}
