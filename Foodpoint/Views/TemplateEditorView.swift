import SwiftUI
import FoodpointKit

/// The "New Meal" template editor (MK-4, meals-feature-design.md §7) —
/// doubles as the "Edit" flow for an existing template (`template != nil`),
/// since both need the same three inputs: a name, a default slot, and a
/// composed ingredient list. Ingredient composition itself is delegated
/// entirely to `MealCompositionEditorView` (MK-2), reused here exactly as
/// that view's own doc comment anticipated — this view only adds the
/// name/slot metadata MK-2's editor doesn't collect, via a plain `Form`
/// around an "Edit Ingredients" button that presents it as a sheet.
///
/// Editing re-instantiates the template's ingredients fresh
/// (`appState.meals.instantiate(template)`) before handing them to the
/// composition editor, so nutrition shown while editing reflects current
/// data — consistent with a template being "a live recipe, re-resolved on
/// each use" (`MealTemplate`'s own doc comment), never a frozen record the
/// way a `MealEntry` is.
struct TemplateEditorView: View {
    /// `nil` for "New Meal"; the template being edited otherwise.
    var template: MealTemplate?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var defaultSlot: MealSlot
    @State private var ingredients: [LoggedIngredient]

    @State private var isLoadingIngredients: Bool
    @State private var loadErrorMessage: String?
    @State private var isShowingLoadError = false
    @State private var isShowingIngredientEditor = false

    init(template: MealTemplate?) {
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _defaultSlot = State(initialValue: template?.defaultSlot ?? MealSlot.current())
        _ingredients = State(initialValue: [])
        _isLoadingIngredients = State(initialValue: template != nil)
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ingredients.isEmpty
    }

    private var editorTitle: String {
        template == nil ? "New Meal" : "Edit Meal"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Meal Name", text: $name)
                }
                Section("Default Slot") {
                    Picker("Slot", selection: $defaultSlot) {
                        ForEach(MealSlot.allCases) { slot in
                            Text(slot.id.capitalized).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Ingredients") {
                    if isLoadingIngredients {
                        HStack {
                            Spacer()
                            ProgressView("Loading Ingredients...")
                            Spacer()
                        }
                    } else if ingredients.isEmpty {
                        Text("No ingredients yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ingredients) { ingredient in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.productName ?? "Unknown Product")
                                Text("\(ingredient.amount.formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unitLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button(ingredients.isEmpty ? "Add Ingredients" : "Edit Ingredients") {
                        isShowingIngredientEditor = true
                    }
                    .disabled(isLoadingIngredients)
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaveDisabled)
                }
            }
            .task {
                await loadInitialIngredientsIfNeeded()
            }
            .sheet(isPresented: $isShowingIngredientEditor) {
                MealCompositionEditorView(initialIngredients: ingredients, title: editorTitle) { updated in
                    ingredients = updated
                }
            }
            .alert("Couldn't Load Template", isPresented: $isShowingLoadError, presenting: loadErrorMessage) { _ in
                Button("OK") { dismiss() }
            } message: { message in
                Text(message)
            }
        }
    }

    /// Instantiates the template being edited exactly once, on first
    /// appearance — `appState.meals.instantiate` makes one network call per
    /// ingredient, so this must not re-run on every view update. A no-op for
    /// "New Meal" (`template == nil`) and for a second appearance after
    /// ingredients have already loaded (`ingredients` non-empty).
    private func loadInitialIngredientsIfNeeded() async {
        guard let template, ingredients.isEmpty else {
            isLoadingIngredients = false
            return
        }
        do {
            ingredients = try await appState.meals.instantiate(template)
        } catch {
            loadErrorMessage = error.localizedDescription
            isShowingLoadError = true
        }
        isLoadingIngredients = false
    }

    /// Persists the edited name/slot/ingredients — `addTemplate` for a new
    /// template, `updateTemplate` (matched by `template.id`) for an existing
    /// one. `ingredients` (`[LoggedIngredient]`, from the reused composition
    /// editor) are demoted back to `[TemplateIngredient]` via
    /// `TemplateIngredient.init(logged:)`, dropping their frozen nutrition
    /// so the saved template resolves it fresh on every future use.
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let templateIngredients = ingredients.map(TemplateIngredient.init(logged:))
        if let template {
            var updated = template
            updated.name = trimmedName
            updated.defaultSlot = defaultSlot
            updated.ingredients = templateIngredients
            appState.meals.updateTemplate(updated)
        } else {
            let newTemplate = MealTemplate(name: trimmedName, defaultSlot: defaultSlot, ingredients: templateIngredients)
            appState.meals.addTemplate(newTemplate)
        }
        dismiss()
    }
}
