import Observation

@Observable
class AppState {
    static let shared = AppState()

    private init() {}

    var items: [FoodItem] = []
    var unitConfigs: [String: ProductUnit] = [:]

    func addProduct(_ product: FoodProduct, unit: ProductUnit? = nil) {
        let resolvedUnit = unitConfigs[product.barcode] ?? unit ?? .items
        unitConfigs[product.barcode] = resolvedUnit

        if let index = items.firstIndex(where: { $0.id == product.barcode }) {
            items[index].quantity += resolvedUnit.quantityPerPackage
        } else {
            items.append(FoodItem(id: product.barcode, product: product, quantity: resolvedUnit.quantityPerPackage, unit: resolvedUnit))
        }
    }

    func setQuantity(_ quantity: Double, forItemID itemID: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }
    }

    func updateUnit(_ unit: ProductUnit, forItemID itemID: String) {
        unitConfigs[itemID] = unit
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].unit = unit
    }

    func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }
}
