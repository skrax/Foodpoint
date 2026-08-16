import Observation

@Observable
class AppState {
    static let shared = AppState()

    private init() {}

    var items: [FoodItem] = []

    func addProduct(_ product: FoodProduct) {
        if let index = items.firstIndex(where: { $0.id == product.barcode }) {
            items[index].quantity += 1
        } else {
            items.append(FoodItem(id: product.barcode, product: product, quantity: 1))
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

    func removeItem(_ itemID: String) {
        items.removeAll { $0.id == itemID }
    }
}
