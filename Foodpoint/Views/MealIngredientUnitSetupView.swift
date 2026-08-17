import SwiftUI
import FoodpointKit

/// Minimal weight/count unit setup for a barcode `MealCompositionEditorView`
/// has never used before (via scan or search) — meals-feature-design.md
/// §6.3. Deliberately smaller than `ScannerView`'s equivalent
/// `unitConfigFields`: there's no "package" concept here, just "how much of
/// this goes in this one ingredient row", so this asks directly for grams
/// per count-unit rather than deriving it from a package weight and a count
/// per package.
///
/// The resulting `ProductUnit` is scoped to this ingredient alone — it is
/// never written to `appState.pantry.unitConfigs`/`unitVariants`, even for a
/// barcode that's also configured there. If the same barcode is later
/// scanned into the pantry too, that's a fully separate, independently
/// configured `ProductUnit`, by design.
struct MealIngredientUnitSetupView: View {
    /// The freshly-resolved product this unit will apply to — shown for
    /// context so the user knows what they're configuring.
    let product: Product
    var onConfirm: (ProductUnit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: UnitTrackingMode = .count
    @State private var countLabelText = "items"
    @State private var gramsPerUnitText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        if let url = product.imageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading) {
                            Text(product.name ?? "Unknown Product")
                                .font(.headline)
                            if let brand = product.brand {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("How is this counted?") {
                    Picker("Tracking", selection: $mode) {
                        ForEach(UnitTrackingMode.allCases) { trackingMode in
                            Text(trackingMode.rawValue).tag(trackingMode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .count {
                        TextField("Count label (e.g. slices, eggs)", text: $countLabelText)
                        TextField("Grams per \(countLabelText.isEmpty ? "item" : countLabelText)", text: $gramsPerUnitText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Text("Scoped to this ingredient only — this won't change how \(product.name ?? "this product") is tracked in your pantry, even if it's already configured there.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("How Is This Counted?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { confirm() }
                }
            }
        }
    }

    private func confirm() {
        let unit: ProductUnit
        switch mode {
        case .weight:
            unit = ProductUnit(label: "g", quantityPerPackage: 1, gramsPerUnit: 1)
        case .count:
            let label = countLabelText.trimmingCharacters(in: .whitespacesAndNewlines)
            unit = ProductUnit(
                label: label.isEmpty ? "items" : label,
                quantityPerPackage: 1,
                gramsPerUnit: gramsPerUnitText.localizedDouble
            )
        }
        onConfirm(unit)
        dismiss()
    }
}
