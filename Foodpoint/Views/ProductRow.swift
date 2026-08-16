import SwiftUI

struct ProductRow: View {
    let product: FoodProduct
    let quantity: Double
    let unitLabel: String

    var body: some View {
        HStack {
            Image(systemName: product.category.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(product.productName ?? "Unknown Product")
                    .font(.headline)
                if let brands = product.brands {
                    Text(brands)
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
