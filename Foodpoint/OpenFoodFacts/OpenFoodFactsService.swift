import Foundation

final class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private init() {}

    func fetchProduct(barcode: String) async throws -> FoodProduct {
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
}
