import SwiftUI
import FoodpointKit

/// "Meals" tab: today a thin placeholder whose only real job is to make
/// `MealCompositionEditorView` (MK-2) reachable — a "+" button presents it
/// as a sheet, and composed meals land in a bare list below. The real Meals
/// tab (a day timeline, templates, planning) lands in later tasks
/// (MK-4/MK-5, on top of MK-3's orchestration); this view exists now purely
/// so the composition editor — and, in particular, its "from history"
/// ingredient source, which reads `appState.meals`' already-logged entries
/// — has something real to acquire ingredients into and reuse.
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
/// (`appState.undoMealEaten(_:)`), the one piece of UI this task's scope
/// needs to make the "log, then undo, then confirm restored exactly" loop
/// actually usable end to end, ahead of the real day timeline (MK-4/MK-5).
struct MealsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingComposer = false
    @State private var insufficientStockMessage: String?
    @State private var isShowingInsufficientStockAlert = false

    private var recentEntries: [MealEntry] {
        appState.meals.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recentEntries.isEmpty {
                    ContentUnavailableView(
                        "No Meals Yet",
                        systemImage: "fork.knife",
                        description: Text("Compose a meal from your pantry, your history, or by scanning or searching for a product.")
                    )
                } else {
                    List {
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
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    /// Plans `ingredients` as a new entry, immediately marks it eaten
    /// (applying the pantry orchestration), and — if that clamped any
    /// `usesFromPantry` ingredient due to insufficient stock — surfaces a
    /// soft note rather than blocking, per meals-feature-design.md §4.4.
    private func logAndMarkEaten(_ ingredients: [LoggedIngredient]) {
        let planned = appState.meals.plan(name: "Ad-hoc Meal", date: Date(), slot: MealSlot.current(), ingredients: ingredients)
        appState.markMealEaten(planned.id)

        let shortIngredients = appState.insufficientStockIngredients(for: planned.id)
        guard !shortIngredients.isEmpty else { return }
        insufficientStockMessage = "Not enough pantry stock for \(shortIngredients.joined(separator: ", ")) — clamped to zero."
        isShowingInsufficientStockAlert = true
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
