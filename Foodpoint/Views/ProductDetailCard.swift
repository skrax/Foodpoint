//
//  ProductDetailCard.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

struct ProductDetailCard: View {
    let product: FoodProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                if let imageUrl = product.imageFrontUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName ?? "Unknown Product")
                        .font(.title3)
                        .bold()
                    
                    Text(product.brands ?? "Unknown Brand")
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

            if let nutriments = product.nutriments {
                Text("Nutrition Facts (per 100g)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)

                HStack {
                    MetricView(label: "Calories", value: "\(Int(nutriments.energyKcal100g ?? 0)) kcal")
                    MetricView(label: "Carbs", value: "\(String(format: "%.1f", nutriments.carbohydrates100g ?? 0))g")
                    MetricView(label: "Protein", value: "\(String(format: "%.1f", nutriments.proteins100g ?? 0))g")
                    MetricView(label: "Fat", value: "\(String(format: "%.1f", nutriments.fat100g ?? 0))g")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }
}