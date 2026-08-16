//
//  Nutriments.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 04.08.26.
//


import Foundation

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

    // `factor` is grams-per-unit / 100, converting these per-100g figures to per-unit.
    func scaled(by factor: Double) -> Nutriments {
        Nutriments(
            energyKcal100g: energyKcal100g.map { $0 * factor },
            proteins100g: proteins100g.map { $0 * factor },
            carbohydrates100g: carbohydrates100g.map { $0 * factor },
            fat100g: fat100g.map { $0 * factor },
            sugars100g: sugars100g.map { $0 * factor },
            fiber100g: fiber100g.map { $0 * factor },
            sodium100g: sodium100g.map { $0 * factor }
        )
    }
}