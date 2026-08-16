import Foundation

/// Errors surfaced by `OpenFoodFactsService`, with user-facing messages
/// via `LocalizedError` for display in consuming apps.
public enum OpenFoodFactsError: Error, LocalizedError {
    case invalidURL
    case productNotFound
    case searchFailed
    case networkError(Error)
    case decodingError

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The barcode URL was invalid."
        case .productNotFound:
            return "Product not found in the Open Food Facts database."
        case .searchFailed:
            return "The search request failed."
        case .networkError(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to parse product details."
        }
    }
}
