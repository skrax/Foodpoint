import Foundation

/// Thin client for the Open Food Facts public product API. Stateless and
/// requires no API key — queries are anonymous per OFF's terms of service.
public final class OpenFoodFactsService {
    public static let shared = OpenFoodFactsService()
    private init() {}

    /// Looks up a product by barcode.
    /// - Throws: `OpenFoodFactsError` for a bad URL, a non-200 response,
    ///   an OFF "not found" status, or a decoding failure.
    public func fetchProduct(barcode: String) async throws -> FoodProduct {
        // Open Food Facts v2 API endpoint
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"

        guard let url = URL(string: urlString) else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // ⚠️ Required by Open Food Facts terms of service:
        request.setValue("MyFoodApp/1.0 (contact@myfoodapp.com)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenFoodFactsError.productNotFound
        }

        do {
            let decodedResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)

            if decodedResponse.status == 1, let product = decodedResponse.product {
                return product
            } else {
                throw OpenFoodFactsError.productNotFound
            }
        } catch {
            throw OpenFoodFactsError.decodingError
        }
    }

    /// Finds products by free-text name/brand — for items with no barcode
    /// to scan (produce, bulk goods). Uses search-a-licious
    /// (`search.openfoodfacts.org`), the API Open Food Facts recommends for
    /// text search — the v2/v3 product API doesn't support it. An empty
    /// result is a normal outcome, not an error; it means zero matches, not
    /// that the search failed.
    /// - Throws: `OpenFoodFactsError` for a bad URL, a non-200 response, or
    ///   a decoding failure.
    public func searchProducts(query: String) async throws -> [SearchedProduct] {
        var components = URLComponents(string: "https://search.openfoodfacts.org/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,image_front_url,nutriscore_grade,categories_tags,nutriments"),
        ]

        guard let url = components?.url else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // ⚠️ Required by Open Food Facts terms of service:
        request.setValue("MyFoodApp/1.0 (contact@myfoodapp.com)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenFoodFactsError.searchFailed
        }

        do {
            let decodedResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return decodedResponse.hits
        } catch {
            throw OpenFoodFactsError.decodingError
        }
    }
}
