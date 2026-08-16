import Foundation

struct ProductUnit {
    var label: String
    var quantityPerPackage: Double
    var gramsPerUnit: Double?

    static let items = ProductUnit(label: "items", quantityPerPackage: 1, gramsPerUnit: nil)
}
