//
//  FoodProduct.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 04.08.26.
//


import Foundation

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