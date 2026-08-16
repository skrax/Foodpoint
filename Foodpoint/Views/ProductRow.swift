import SwiftUI

/// Shared list row (name, brand, category icon, quantity) used by `ItemsView`.
struct ProductRow: View {
    let product: Product
    let quantity: Double
    let unitLabel: String

    var body: some View {
        HStack {
            Image(systemName: product.category.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(product.name ?? "Unknown Product")
                    .font(.headline)
                if let brand = product.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(unitLabel)")
                .foregroundStyle(.secondary)
        }
    }
}
