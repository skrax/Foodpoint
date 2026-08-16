import SwiftUI
import FoodpointKit

/// Lists every nutrition data set remembered for a barcode — Open Food
/// Facts' own figures plus any custom entries — each tagged with a source
/// badge, with add/edit/delete and "Make Default" to choose which one is
/// used for display and per-unit math. Mirrors `PackageVariantsView`.
struct NutritionVariantsView: View {
    let barcode: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editingVariant: NutritionVariant?
    @State private var isAddingVariant = false

    private var variants: [NutritionVariant] {
        appState.allNutritionVariants(forBarcode: barcode)
    }

    private var defaultID: UUID? {
        appState.nutritionConfigs[barcode]?.id
    }

    var body: some View {
        NavigationStack {
            Group {
                if variants.isEmpty {
                    ContentUnavailableView(
                        "No Nutrition Data",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Open Food Facts has no nutrition data for this product yet. Add your own with the + button.")
                    )
                } else {
                    List {
                        ForEach(variants) { variant in
                            row(for: variant)
                                .swipeActions {
                                    if variant.id != defaultID {
                                        Button(role: .destructive) {
                                            appState.removeNutritionVariant(variant.id, forBarcode: barcode)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingVariant = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingVariant) { variant in
                NutritionVariantEditForm(barcode: barcode, existing: variant, isDefault: variant.id == defaultID)
            }
            .sheet(isPresented: $isAddingVariant) {
                NutritionVariantEditForm(barcode: barcode, existing: nil)
            }
        }
    }

    private func row(for variant: NutritionVariant) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(variant.name)
                        .font(.headline)
                    sourceBadge(variant.source)
                    if variant.id == defaultID {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(summary(for: variant.nutrition))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                editingVariant = variant
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingVariant = variant
        }
    }

    private func sourceBadge(_ source: NutritionSource) -> some View {
        Text(source.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((source == .openFoodFacts ? Color.blue : Color.orange).opacity(0.2))
            .clipShape(Capsule())
    }

    private func summary(for nutrition: Nutrition) -> String {
        let calories = Int(nutrition.energyKcal100g ?? 0)
        let protein = String(format: "%.1f", nutrition.proteins100g ?? 0)
        let carbs = String(format: "%.1f", nutrition.carbohydrates100g ?? 0)
        let fat = String(format: "%.1f", nutrition.fat100g ?? 0)
        return "\(calories) kcal · \(protein)g protein · \(carbs)g carbs · \(fat)g fat"
    }
}
