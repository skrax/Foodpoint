import Foundation

/// A product as returned by the Open Food Facts v2 API. Decoded from
/// whichever fields OFF includes for that barcode — most are optional
/// because OFF's data coverage varies a lot per product.
///
/// This is a wire-format DTO, not a domain model — consumers should map it
/// to their own type rather than passing it around directly.
public struct FoodProduct: Decodable, Identifiable {
    public var id: String { barcode }
    public let barcode: String
    public let productName: String?
    public let brands: String?
    public let imageFrontUrl: String?
    /// OFF's free-text package quantity (e.g. "750g").
    public let quantity: String?
    public let nutriScoreGrade: String?
    public let ingredientsText: String?
    /// Nutrition facts per 100g.
    public let nutriments: Nutriments?
    /// OFF's hierarchical category tags (e.g. `["en:dairies", "en:cheeses"]`).
    public let categoriesTags: [String]?

    enum CodingKeys: String, CodingKey {
        case barcode = "code"
        case productName = "product_name"
        case brands
        case imageFrontUrl = "image_front_url"
        case quantity
        case nutriScoreGrade = "nutriscore_grade"
        case ingredientsText = "ingredients_text"
        case nutriments
        case categoriesTags = "categories_tags"
    }
}
