import Foundation

/// A product the user has saved, with how much of it remains.
///
/// One `FoodItem` exists per barcode in `AppState.items` — re-scanning the
/// same barcode increments `quantity` rather than creating a duplicate.
struct FoodItem: Identifiable {
    /// The product's barcode, also used as `AppState.unitConfigs`'s key.
    let id: String
    var product: Product
    /// Amount remaining, expressed in `unit.label` (e.g. 12 "bars", 650 "g").
    var quantity: Double
    var unit: ProductUnit
}
