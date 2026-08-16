//
//  FoodProduct.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 04.08.26.
//


import Foundation

/// A product as returned by the Open Food Facts v2 API. Decoded from
/// whichever fields OFF includes for that barcode — most are optional
/// because OFF's data coverage varies a lot per product.
struct FoodProduct: Decodable, Identifiable {
    var id: String { barcode }
    let barcode: String
    let productName: String?
    let brands: String?
    let imageFrontUrl: String?
    /// OFF's free-text package quantity (e.g. "750g"), not used for unit
    /// math — see `ProductUnit` for the app's own configured quantity.
    let quantity: String?
    let nutriScoreGrade: String?
    let ingredientsText: String?
    /// Nutrition facts per 100g. Scaled to per-count via `Nutriments.scaled(by:)`.
    let nutriments: Nutriments?
    /// OFF's hierarchical category tags (e.g. `["en:dairies", "en:cheeses"]`),
    /// used by `FoodProduct.category` to guess a display icon.
    let categoriesTags: [String]?

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