import Foundation

/// A product as returned by Open Food Facts' search-a-licious text-search
/// API (`search.openfoodfacts.org`) — a distinct wire format from
/// `FoodProduct` (the by-barcode v2 API's shape), not a variant of it.
/// Confirmed against the live API rather than assumed: `nutriments` uses
/// the same per-100g field names either way, but `brands` is an array
/// here (`["Fresh Banana"]`) where the by-barcode endpoint returns a
/// single comma-separated string (`"Nutella, Ferrero"`) — decoding one as
/// the other would silently fail or crash, so this stays a separate type
/// rather than folding into `FoodProduct`.
public struct SearchedProduct: Decodable, Identifiable {
    public var id: String { barcode }
    public let barcode: String
    public let productName: String?
    public let brands: [String]?
    public let imageFrontUrl: String?
    public let nutriScoreGrade: String?
    /// Nutrition facts per 100g. Same shape as `FoodProduct.nutriments`.
    public let nutriments: Nutriments?
    public let categoriesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case barcode = "code"
        case productName = "product_name"
        case brands
        case imageFrontUrl = "image_front_url"
        case nutriScoreGrade = "nutriscore_grade"
        case nutriments
        case categoriesTags = "categories_tags"
    }
}
