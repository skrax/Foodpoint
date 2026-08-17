import SwiftUI
import FoodpointKit

/// "Meals" tab: today a thin placeholder whose only real job is to make
/// `MealCompositionEditorView` (MK-2) reachable — a "+" button presents it
/// as a sheet, and composed meals land in a bare list below. The real Meals
/// tab (a day timeline, templates, planning, pantry decrementing on log)
/// lands in later tasks (MK-4/MK-5, on top of MK-3's orchestration); this
/// view exists now purely so the composition editor — and, in particular,
/// its "from history" ingredient source, which reads `appState.meals`'
/// already-logged entries — has something real to acquire ingredients into
/// and reuse.
///
/// **Deliberately provisional:** this calls `appState.meals.logEaten`
/// directly on "Done", which does create a real `.eaten` `MealEntry` (so
/// "from history" has data to show), but — unlike MK-3's eventual
/// `AppState.markMealEaten`-style orchestration
/// (package-architecture.md §3.5) — it never touches
/// `appState.pantry`'s quantities, even for ingredients with "Use from
/// pantry" on. MK-3 replaces this call site with the real one, which
/// additionally decrements pantry stock and supports undo.
struct MealsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingComposer = false

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
                    List(recentEntries) { entry in
                        entryRow(entry)
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
                    appState.meals.logEaten(name: "Ad-hoc Meal", date: Date(), slot: MealSlot.current(), ingredients: ingredients)
                }
            }
        }
    }

    private func entryRow(_ entry: MealEntry) -> some View {
        let completeness = MealStore.completeness(for: entry.ingredients)
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        let prefix = completeness.isComplete ? "" : "≥ "
        return VStack(alignment: .leading, spacing: 2) {
            Text(entry.name)
                .font(.headline)
            Text("\(entry.slot.id.capitalized) · \(entry.ingredients.count) ingredient\(entry.ingredients.count == 1 ? "" : "s") · \(prefix)\(kcal) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
