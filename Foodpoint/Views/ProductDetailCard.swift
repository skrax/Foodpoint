//
//  ProductDetailCard.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

/// Product summary card: image, name, brand, category, Nutri-Score, and
/// per-100g nutrition facts. Used in the scanner, and reused (nutrition
/// facts included) at the top of `ItemDetailView`.
struct ProductDetailCard: View {
    let product: Product
    /// Overrides `product.nutrition` for display — e.g. the scanner showing
    /// a barcode's already-resolved nutrition variant instead of this
    /// scan's raw (possibly empty) Open Food Facts fetch. `nil` uses
    /// `product.nutrition` as-is.
    var nutritionOverride: Nutrition?
    /// Shown as a badge next to "Nutrition Facts" — e.g. "Open Food Facts"
    /// or "Custom" — so it's always clear where the numbers came from.
    /// `nil` shows no badge.
    var nutritionSource: NutritionSource?

    private var nutrition: Nutrition? { nutritionOverride ?? product.nutrition }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                if let url = product.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name ?? "Unknown Product")
                        .font(.title3)
                        .bold()

                    Text(product.brand ?? "Unknown Brand")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Label(product.category.rawValue, systemImage: product.category.icon)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)

                        if let score = product.nutriScoreGrade?.uppercased() {
                            Text("Nutri-Score: \(score)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Divider()

            if let nutrition {
                HStack(spacing: 6) {
                    Text("Nutrition Facts (per 100g)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)

                    if let nutritionSource {
                        Text(nutritionSource.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((nutritionSource == .openFoodFacts ? Color.blue : Color.orange).opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    MetricView(label: "Calories", value: "\(Int(nutrition.energyKcal100g ?? 0)) kcal")
                    MetricView(label: "Carbs", value: "\(String(format: "%.1f", nutrition.carbohydrates100g ?? 0))g")
                    MetricView(label: "Protein", value: "\(String(format: "%.1f", nutrition.proteins100g ?? 0))g")
                    MetricView(label: "Fat", value: "\(String(format: "%.1f", nutrition.fat100g ?? 0))g")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }
}
