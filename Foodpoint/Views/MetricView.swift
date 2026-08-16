//
//  MetricView.swift
//  Foodpoint
//
//  Created by Fabian Seidl on 06.08.26.
//


import SwiftUI

/// A small labeled stat tile (e.g. "Calories" / "210 kcal"), used in the
/// nutrition-facts rows of `ProductDetailCard` and `ItemDetailView`.
struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.footnote).bold()
        }
        .frame(maxWidth: .infinity)
    }
}