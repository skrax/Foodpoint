import Foundation

struct Location: Identifiable {
    let id: UUID
    var name: String
    var items: [LocationItem] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct LocationItem: Identifiable {
    let id: String
    var product: FoodProduct
    var quantity: Int
}
