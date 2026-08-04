//
//  OpenFoodFactsResponse.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 04.08.26.
//


import Foundation

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