import SwiftUI

struct ProductRow: View {
    let product: FoodProduct
    let quantity: Int

    var body: some View {
        HStack {
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
            Text("×\(quantity)")
                .foregroundStyle(.secondary)
        }
    }
}
