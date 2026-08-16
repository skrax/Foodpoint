import Observation

@Observable
class AppState {
    static let shared = AppState()

    let defaultLocationID: Location.ID
    var locations: [Location]

    private init() {
        let defaultLocation = Location(name: "Default", isDefault: true)
        defaultLocationID = defaultLocation.id
        locations = [defaultLocation]
    }

    func addLocation(name: String, icon: String) {
        locations.append(Location(name: name, icon: icon))
    }

    func addProduct(_ product: FoodProduct, toLocationWithID locationID: Location.ID) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationID }) else { return }
        if let itemIndex = locations[locationIndex].items.firstIndex(where: { $0.id == product.barcode }) {
            locations[locationIndex].items[itemIndex].quantity += 1
        } else {
            locations[locationIndex].items.append(LocationItem(id: product.barcode, product: product, quantity: 1))
        }
    }

    func setQuantity(_ quantity: Double, forItemID itemID: String, inLocationWithID locationID: Location.ID) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationID }),
              let itemIndex = locations[locationIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
        if quantity <= 0 {
            locations[locationIndex].items.remove(at: itemIndex)
        } else {
            locations[locationIndex].items[itemIndex].quantity = quantity
        }
    }

    func removeItem(_ itemID: String, fromLocationWithID locationID: Location.ID) {
        guard let locationIndex = locations.firstIndex(where: { $0.id == locationID }) else { return }
        locations[locationIndex].items.removeAll { $0.id == itemID }
    }
}
