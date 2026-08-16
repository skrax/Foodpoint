import Foundation

struct FoodItem: Identifiable {
    let id: String
    var product: FoodProduct
    var quantity: Double
    var unit: ProductUnit
}
