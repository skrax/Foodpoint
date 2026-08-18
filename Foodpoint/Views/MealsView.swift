import SwiftUI
import FoodpointKit

/// "Meals" tab: still a thin placeholder around the composer/logging loop
/// rather than the real day timeline (still MK-5 territory), but now
/// surfaces `TemplatesListView` (MK-4) as its top entry point — "Templates,"
/// a `NavigationLink` row above the recent-entries list, is this file's
/// entire MK-4 footprint by design: all of that task's real UI (the
/// templates list itself, one-tap logging, template creation/edit/rename/
/// delete) lives in `TemplatesListView.swift`/`TemplateEditorView.swift`,
/// kept out of this file so its diff here stays small — two sibling tasks
/// (MK-5, MK-6) also touch this file in their own branches.
///
/// **The real logging loop, wired up (MK-3):** "Done" plans the composed
/// ingredients as an entry (`appState.meals.plan`), then immediately calls
/// `appState.markMealEaten(_:)` to transition it to `.eaten` and apply its
/// pantry side effects (package-architecture.md §3.5) — the two-step path
/// because `markMealEaten` only operates on a `.planned` entry, matching
/// `MealStore.markEaten`'s own contract. If any `usesFromPantry` ingredient
/// came up short against pantry stock, `appState.insufficientStockIngredients(for:)`
/// reports it right after and this view surfaces it as a soft, non-blocking
/// alert (meals-feature-design.md §4.4) — logging already succeeded either
/// way. Each `.eaten` row also gets a swipe-to-undo action
/// (`appState.undoMealEaten(_:)`), the one piece of UI MK-3's scope needed
/// to make the "log, then undo, then confirm restored exactly" loop usable
/// end to end, ahead of the real day timeline (MK-5).
///
/// **"Remember this meal?" (MK-4):** once an ad-hoc log (and its optional
/// insufficient-stock note) settles, `RememberMealPromptModifier` offers to
/// promote the just-logged ingredients into a `MealTemplate` — see
/// `logAndMarkEaten`/`RememberMealPrompt.swift` for the full sequencing
/// (the two alerts are never shown simultaneously).
struct MealsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingComposer = false
    @State private var insufficientStockMessage: String?
    @State private var isShowingInsufficientStockAlert = false

    /// The ad-hoc meal's ingredients, held onto from the moment they're
    /// logged until the "Remember this meal?" prompt is dismissed one way or
    /// another — `RememberMealPromptModifier`'s `presenting:` data.
    @State private var pendingRememberIngredients: [LoggedIngredient]?
    @State private var isShowingRememberPrompt = false
    @State private var rememberMealName = ""

    private var recentEntries: [MealEntry] {
        appState.meals.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TemplatesListView()
                    } label: {
                        HStack {
                            Label("Templates", systemImage: "star.fill")
                            Spacer()
                            Text("\(appState.meals.templates.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if recentEntries.isEmpty {
                    ContentUnavailableView(
                        "No Meals Yet",
                        systemImage: "fork.knife",
                        description: Text("Compose a meal from your pantry, your history, or by scanning or searching for a product.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section("Recent") {
                        ForEach(recentEntries) { entry in
                            entryRow(entry)
                                .swipeActions {
                                    if entry.status == .eaten {
                                        Button("Undo") {
                                            appState.undoMealEaten(entry.id)
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingComposer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingComposer) {
                MealCompositionEditorView { ingredients in
                    guard !ingredients.isEmpty else { return }
                    logAndMarkEaten(ingredients)
                }
            }
            .alert("Insufficient Stock", isPresented: $isShowingInsufficientStockAlert, presenting: insufficientStockMessage) { _ in
                Button("OK") { isShowingRememberPrompt = true }
            } message: { message in
                Text(message)
            }
            .rememberMealPrompt(
                isPresented: $isShowingRememberPrompt,
                pendingIngredients: pendingRememberIngredients,
                name: $rememberMealName,
                onSaveVariant: { ingredients in
                    saveAsTemplate(ingredients)
                    pendingRememberIngredients = nil
                    rememberMealName = ""
                },
                onJustThisOnce: {
                    pendingRememberIngredients = nil
                    rememberMealName = ""
                },
                onCancel: {
                    pendingRememberIngredients = nil
                    rememberMealName = ""
                }
            )
        }
    }

    /// Plans `ingredients` as a new entry, immediately marks it eaten
    /// (applying the pantry orchestration), and then offers "Remember this
    /// meal?" (MK-4). If pantry stock also came up short for any
    /// `usesFromPantry` ingredient, that soft note (meals-feature-design.md
    /// §4.4) is shown first — its own "OK" button is what actually triggers
    /// the remember prompt in that case — so the two alerts are never
    /// presented at the same time.
    private func logAndMarkEaten(_ ingredients: [LoggedIngredient]) {
        let planned = appState.meals.plan(name: "Ad-hoc Meal", date: Date(), slot: MealSlot.current(), ingredients: ingredients)
        appState.markMealEaten(planned.id)
        pendingRememberIngredients = ingredients

        let shortIngredients = appState.insufficientStockIngredients(for: planned.id)
        guard !shortIngredients.isEmpty else {
            isShowingRememberPrompt = true
            return
        }
        insufficientStockMessage = "Not enough pantry stock for \(shortIngredients.joined(separator: ", ")) — clamped to zero."
        isShowingInsufficientStockAlert = true
    }

    /// "Save Variant" on the remember prompt: promotes `ingredients` into a
    /// new `MealTemplate`, defaulting to today's current slot (the same
    /// default `logAndMarkEaten` gave the ad-hoc entry itself) and an
    /// "Untitled Meal" name if the field was left blank rather than
    /// discarding the save outright.
    private func saveAsTemplate(_ ingredients: [LoggedIngredient]) {
        guard !ingredients.isEmpty else { return }
        let trimmedName = rememberMealName.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = MealTemplate(
            name: trimmedName.isEmpty ? "Untitled Meal" : trimmedName,
            defaultSlot: MealSlot.current(),
            ingredients: ingredients.map(TemplateIngredient.init(logged:))
        )
        appState.meals.addTemplate(template)
    }

    private func entryRow(_ entry: MealEntry) -> some View {
        let completeness = MealStore.completeness(for: entry.ingredients)
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        let prefix = completeness.isComplete ? "" : "≥ "
        return VStack(alignment: .leading, spacing: 2) {
            Text(entry.name)
                .font(.headline)
            Text("\(entry.slot.id.capitalized) · \(entry.ingredients.count) ingredient\(entry.ingredients.count == 1 ? "" : "s") · \(prefix)\(kcal) kcal · \(entry.status == .eaten ? "Eaten" : "Planned")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
