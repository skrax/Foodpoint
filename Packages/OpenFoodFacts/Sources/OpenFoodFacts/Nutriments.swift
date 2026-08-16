import Foundation

/// Nutrition facts as reported by Open Food Facts, always per 100g of product.
public struct Nutriments: Decodable {
    public let energyKcal100g: Double?
    public let proteins100g: Double?
    public let carbohydrates100g: Double?
    public let fat100g: Double?
    public let sugars100g: Double?
    public let fiber100g: Double?
    public let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case sodium100g = "sodium_100g"
    }
}
