//
//  OpenFoodFactsError.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 04.08.26.
//


import Foundation

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