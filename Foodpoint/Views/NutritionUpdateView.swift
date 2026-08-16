import SwiftUI

/// Shown when a known barcode's Open Food Facts nutrition data is new or
/// has changed since it was last seen, letting the user pick which values
/// to use going forward. Either choice updates the remembered
/// Open-Food-Facts variant, so the same change isn't asked about again on
/// the next scan — only "Later" leaves it unresolved.
struct NutritionUpdateView: View {
    let barcode: String
    let currentVariant: NutritionVariant?
    let updatedOFFVariant: NutritionVariant
    var onResolved: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Open Food Facts nutrition data is available for this product. Which values should be used?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top)

                    if let currentVariant {
                        optionCard(title: currentVariant.name, badge: "Current", nutrition: currentVariant.nutrition, action: keepCurrent)
                    }

                    optionCard(title: updatedOFFVariant.name, badge: nil, nutrition: updatedOFFVariant.nutrition, action: useOpenFoodFacts)
                }
                .padding(.bottom)
            }
            .navigationTitle("Nutrition Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private func optionCard(title: String, badge: String?, nutrition: Nutrition, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private func keepCurrent() {
        appState.refreshNutritionVariant(updatedOFFVariant, forBarcode: barcode)
        finish()
    }

    private func useOpenFoodFacts() {
        appState.setDefaultNutritionVariant(updatedOFFVariant, forBarcode: barcode)
        finish()
    }

    private func finish() {
        onResolved()
        dismiss()
    }
}
