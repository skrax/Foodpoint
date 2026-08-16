import SwiftUI

struct ItemDetailView: View {
    let itemID: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var item: FoodItem? {
        appState.items.first { $0.id == itemID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let item {
                    ProductDetailCard(product: item.product)
                    Stepper(
                        "Quantity: \(item.quantity.formatted(.number.precision(.fractionLength(0...2))))",
                        value: Binding(
                            get: { item.quantity },
                            set: { appState.setQuantity($0, forItemID: itemID) }
                        ),
                        in: 0...99,
                        step: 0.5
                    )
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(item?.product.productName ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }
}
