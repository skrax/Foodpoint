import Foundation

struct Location: Identifiable {
    let id: UUID
    var name: String
    var items: [LocationItem] = []
    let isDefault: Bool

    init(id: UUID = UUID(), name: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

struct LocationItem: Identifiable {
    let id: String
    var product: FoodProduct
    var quantity: Int
}
