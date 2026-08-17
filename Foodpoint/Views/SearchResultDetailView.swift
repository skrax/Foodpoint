import SwiftUI
import FoodpointKit

/// Nutrition inspection screen for one `ProductSearchView` search result,
/// pushed (not presented as a sheet) via `.navigationDestination(item:)` on
/// `ProductSearchView`'s own `NavigationStack` — see `inspectedProductID`
/// there. Read-only: it just reuses `ProductDetailCard` to show what Open
/// Food Facts returned for this candidate, so the user can compare it
/// against other results (e.g. "Banana (Morrisons)" vs. "Banana
/// (fairtrade)") before tapping the row itself to select one. Selecting is
/// unaffected by this screen — it only happens via the row's own tap
/// gesture back on the results list.
struct SearchResultDetailView: View {
    let product: Product

    var body: some View {
        ScrollView {
            ProductDetailCard(product: product)
        }
        .navigationTitle(product.name ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
    }
}
