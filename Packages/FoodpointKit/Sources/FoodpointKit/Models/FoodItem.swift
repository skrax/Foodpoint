import Foundation

/// A product the user has saved, with how much of it remains.
///
/// One `FoodItem` exists per barcode in `AppState.items` — re-scanning the
/// same barcode increments `quantity` rather than creating a duplicate.
public struct FoodItem: Identifiable {
    /// The product's barcode, also used as `AppState.unitConfigs`'s key.
    public let id: String
    public var product: Product
    /// Amount remaining, expressed in `unit.label` (e.g. 12 "bars", 650 "g").
    public var quantity: Double
    public var unit: ProductUnit

    public init(id: String, product: Product, quantity: Double, unit: ProductUnit) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.unit = unit
    }
}
