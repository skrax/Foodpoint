import Foundation

/// Envelope returned by the OFF v2 product endpoint, wrapping the actual
/// `FoodProduct` payload plus a status flag for "not found" responses.
/// Internal — only `OpenFoodFactsService` needs this shape.
struct OpenFoodFactsResponse: Decodable {
    /// 1 = found, 0 = product not found.
    let status: Int
    let statusVerbose: String
    let product: FoodProduct?

    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}
