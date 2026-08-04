import Foundation

// Top-level API Response
struct OpenFoodFactsResponse: Decodable {
    let status: Int          // 1 = found, 0 = product not found
    let statusVerbose: String
    let product: FoodProduct?

    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

// Core Product Model
struct FoodProduct: Decodable, Identifiable {
    var id: String { barcode }
    let barcode: String
    let productName: String?
    let brands: String?
    let imageFrontUrl: String?
    let quantity: String?
    let nutriScoreGrade: String?
    let ingredientsText: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case barcode = "code"
        case productName = "product_name"
        case brands
        case imageFrontUrl = "image_front_url"
        case quantity
        case nutriScoreGrade = "nutriscore_grade"
        case ingredientsText = "ingredients_text"
        case nutriments
    }
}

// Nutritional Information (per 100g)
struct Nutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let sodium100g: Double?

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

enum OpenFoodFactsError: Error, LocalizedError {
    case invalidURL
    case productNotFound
    case networkError(Error)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The barcode URL was invalid."
        case .productNotFound:
            return "Product not found in the Open Food Facts database."
        case .networkError(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to parse product details."
        }
    }
}

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
