import SwiftUI
import FoodpointKit

/// Add or edit a single nutrition data set, per 100g. Open-Food-Facts-sourced
/// entries are read-only — their name and numbers should reflect exactly
/// what OFF reported; add a custom entry instead if they're wrong. Custom
/// entries are fully editable. Mirrors `VariantEditForm`.
struct NutritionVariantEditForm: View {
    let barcode: String
    let existing: NutritionVariant?
    var isDefault: Bool = false

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var sugarsText = ""
    @State private var fiberText = ""
    @State private var sodiumText = ""
    @State private var isShowingDeleteConfirmation = false

    private var isReadOnly: Bool {
        existing?.source == .openFoodFacts
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. My Values)", text: $name)
                        .disabled(isReadOnly)
                }
                Section("Nutrition per 100g") {
                    numberField("Calories (kcal)", text: $caloriesText)
                    numberField("Protein (g)", text: $proteinText)
                    numberField("Carbs (g)", text: $carbsText)
                    numberField("Fat (g)", text: $fatText)
                    numberField("Sugars (g)", text: $sugarsText)
                    numberField("Fiber (g)", text: $fiberText)
                    numberField("Sodium (g)", text: $sodiumText)
                }

                if isReadOnly {
                    Section {
                        Text("These values come from Open Food Facts and can't be edited directly. Add a custom entry instead if they're wrong.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if existing != nil, !isDefault {
                    Section {
                        Button("Make Default") {
                            makeDefault()
                        }
                    }
                    Section {
                        Button("Delete Variant", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Nutrition Values" : "Edit Nutrition Values")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isReadOnly)
                }
            }
            .onAppear(perform: populate)
            .alert("Delete \"\(name)\"?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .disabled(isReadOnly)
                .foregroundStyle(isReadOnly ? .secondary : .primary)
        }
    }

    private func populate() {
        guard let existing else {
            name = "My Values"
            return
        }
        name = existing.name
        let n = existing.nutrition
        caloriesText = n.energyKcal100g.map(formatted) ?? ""
        proteinText = n.proteins100g.map(formatted) ?? ""
        carbsText = n.carbohydrates100g.map(formatted) ?? ""
        fatText = n.fat100g.map(formatted) ?? ""
        sugarsText = n.sugars100g.map(formatted) ?? ""
        fiberText = n.fiber100g.map(formatted) ?? ""
        sodiumText = n.sodium100g.map(formatted) ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nutrition = Nutrition(
            energyKcal100g: caloriesText.localizedDouble,
            proteins100g: proteinText.localizedDouble,
            carbohydrates100g: carbsText.localizedDouble,
            fat100g: fatText.localizedDouble,
            sugars100g: sugarsText.localizedDouble,
            fiber100g: fiberText.localizedDouble,
            sodium100g: sodiumText.localizedDouble
        )
        let variant = NutritionVariant(
            id: existing?.id ?? UUID(),
            name: trimmedName.isEmpty ? "My Values" : trimmedName,
            nutrition: nutrition,
            source: .custom
        )

        if existing != nil {
            appState.updateNutritionVariant(variant, forBarcode: barcode)
        } else if appState.nutritionConfigs[barcode] == nil {
            appState.setDefaultNutritionVariant(variant, forBarcode: barcode)
        } else {
            appState.addNutritionVariant(variant, forBarcode: barcode)
        }
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        appState.removeNutritionVariant(existing.id, forBarcode: barcode)
        dismiss()
    }

    private func makeDefault() {
        guard let existing else { return }
        appState.makeNutritionDefault(existing.id, forBarcode: barcode)
        dismiss()
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
