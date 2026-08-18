import SwiftUI
import FoodpointKit

/// The Meals tab's day timeline (MK-5, meals-feature-design.md §10) — "Meals
/// tab home is the day timeline, opening on today." Renders one calendar
/// day at a time: date navigation, a day nutrition summary (eaten vs.
/// planned, kept as two separate figures per §8.1), and entries grouped by
/// `MealSlot` in `MealStore.entriesGroupedBySlot(on:)`'s fixed order.
///
/// **Creating an entry:** the "+" menu picks a slot, then presents the same
/// `MealCompositionEditorView` MK-2/MK-3 already use. Whether the result
/// becomes `.planned` or `.eaten` is decided purely by `selectedDate`: a
/// future day calls `appState.meals.plan` and stops there — no pantry
/// orchestration runs at all, so a plan has zero effect on stock or on
/// today's eaten totals until it's actually ticked off (meals-feature-design.md
/// §5). Today (or a past day, treated the same as "I already ate this") goes
/// through the existing two-step `plan` + `appState.markMealEaten(_:)` path
/// MK-3 built, unchanged.
///
/// **Tick-off and undo:** a planned entry gets a prominent checkmark button
/// that calls `appState.markMealEaten(_:)` — the *same* MK-3 orchestration
/// a direct log uses, not a parallel system (meals-feature-design.md §5's
/// "same object in different states"). An eaten entry keeps MK-3's
/// swipe-to-undo action (`appState.undoMealEaten(_:)`). Both paths reuse
/// MK-3's insufficient-stock alert for a post-hoc clamp.
///
/// **The soft stock signal:** each planned row also shows
/// `appState.stockShortfalls(for:)` — a live, read-only comparison against
/// current pantry stock (never a reservation, meals-feature-design.md §12
/// #5) — as a "needs 6 eggs, you have 4"-style caption, recomputed on every
/// render rather than cached at plan time.
///
/// Planned rows are rendered with a visible outline to distinguish them
/// from filled eaten rows, per §10's "planned entries render visually
/// distinct (outlined rather than filled)."
///
/// **MK-6 additions**, folded in here rather than left on the flat-list
/// placeholder MK-6 was written against in parallel: the day totals header
/// is `DayTotalsHeaderView` (richer than this view's own first-cut
/// eaten/planned line — full macro breakdown plus a completeness note,
/// reading off the same `MealStore.dayTotal(for:)`), a leading toolbar menu
/// reaches `RangeSummaryView` (week/month) and `MostConsumedView`, and each
/// row now pushes `MealDetailView` for that entry's ingredients and
/// nutrition-source provenance mix. The row push uses
/// `.navigationDestination(item:)` keyed on the entry's `id` (looked up live
/// against `appState.meals.entries`, rather than requiring `MealEntry` to be
/// `Hashable`) with the row's own `.contentShape(Rectangle())` +
/// `.onTapGesture` — the same nested-tappable-controls-safe pattern already
/// established by `PackageVariantsView.row(for:)` and reused by UX-3's
/// search-result rows — so the row push and the planned-row's separate
/// tick-off `Button` don't conflict.
struct DayTimelineView: View {
    @Environment(AppState.self) private var appState

    /// The day currently on screen, always normalized to its start-of-day —
    /// comparisons against "today"/"future" throughout this view rely on
    /// that normalization holding.
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    @State private var isShowingComposer = false
    /// The slot chosen from the "+" menu for the entry about to be
    /// composed — set right before `isShowingComposer` flips on, read once
    /// the composition editor calls back with `onDone`.
    @State private var pendingSlot: MealSlot = .current()

    @State private var insufficientStockMessage: String?
    @State private var isShowingInsufficientStockAlert = false

    /// The id of the entry currently pushed to `MealDetailView`, or `nil`
    /// when the timeline itself is on screen. Keyed on `id` rather than the
    /// entry itself since `MealEntry` isn't `Hashable`.
    @State private var selectedEntryID: MealEntry.ID?

    private var calendar: Calendar { .current }

    private var isFutureDay: Bool {
        selectedDate > calendar.startOfDay(for: Date())
    }

    private var groupedEntries: [(slot: MealSlot, entries: [MealEntry])] {
        appState.meals.entriesGroupedBySlot(on: selectedDate)
    }

    private var hasAnyEntries: Bool {
        groupedEntries.contains { !$0.entries.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            dateNavigationHeader
            Divider()
            DayTotalsHeaderView(date: selectedDate)
                .padding(.vertical, 6)
            Divider()

            if hasAnyEntries {
                List {
                    ForEach(groupedEntries, id: \.slot) { group in
                        if !group.entries.isEmpty {
                            Section(displayName(for: group.slot)) {
                                ForEach(group.entries) { entry in
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
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "No Meals This Day",
                    systemImage: "fork.knife",
                    description: Text(isFutureDay ? "Plan a meal for this day." : "Log a meal from your pantry, your history, or by scanning or searching for a product.")
                )
                Spacer()
            }
        }
        .navigationTitle("Meals")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                summaryMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                addMealMenu
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            MealCompositionEditorView { ingredients in
                guard !ingredients.isEmpty else { return }
                addEntry(ingredients: ingredients, slot: pendingSlot)
            }
        }
        .navigationDestination(item: $selectedEntryID) { entryID in
            if let entry = appState.meals.entries.first(where: { $0.id == entryID }) {
                MealDetailView(entry: entry)
            }
        }
        .alert("Insufficient Stock", isPresented: $isShowingInsufficientStockAlert, presenting: insufficientStockMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Date navigation

    private var dateNavigationHeader: some View {
        HStack {
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = calendar.startOfDay(for: Date())
                }
            } label: {
                VStack(spacing: 2) {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var dateTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func changeDate(by days: Int) {
        guard let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate
    }

    // MARK: - Summary menu (MK-6: range summary, most consumed)

    private var summaryMenu: some View {
        Menu {
            NavigationLink {
                RangeSummaryView()
            } label: {
                Label("Range Summary", systemImage: "calendar")
            }
            NavigationLink {
                MostConsumedView()
            } label: {
                Label("Most Consumed", systemImage: "chart.bar")
            }
        } label: {
            Image(systemName: "chart.bar.doc.horizontal")
        }
    }

    // MARK: - Adding an entry

    private var addMealMenu: some View {
        Menu {
            ForEach(MealSlot.allCases) { slot in
                Button {
                    pendingSlot = slot
                    isShowingComposer = true
                } label: {
                    Label(displayName(for: slot), systemImage: icon(for: slot))
                }
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    /// Turns a composed ingredient list into a `MealEntry` on `selectedDate`
    /// at `slot`. A future day only plans it (`appState.meals.plan`) and
    /// stops — no pantry orchestration runs, so this has zero effect on
    /// stock or on today's totals until a later tick-off
    /// (meals-feature-design.md §5). Today or an earlier day goes through
    /// the same two-step plan-then-mark-eaten path MK-3 built for the
    /// original ad-hoc composer, unchanged, including its soft
    /// insufficient-stock note.
    private func addEntry(ingredients: [LoggedIngredient], slot: MealSlot) {
        if isFutureDay {
            appState.meals.plan(name: "Planned Meal", date: selectedDate, slot: slot, ingredients: ingredients)
            return
        }

        let planned = appState.meals.plan(name: "Ad-hoc Meal", date: selectedDate, slot: slot, ingredients: ingredients)
        appState.markMealEaten(planned.id)
        presentInsufficientStockAlertIfNeeded(for: planned.id)
    }

    // MARK: - Tick-off

    /// Ticks a planned entry off via `appState.markMealEaten(_:)` — the same
    /// MK-3 orchestration a direct log uses (meals-feature-design.md §5) —
    /// then surfaces MK-3's existing soft insufficient-stock note if
    /// anything clamped.
    private func tickOff(_ entry: MealEntry) {
        appState.markMealEaten(entry.id)
        presentInsufficientStockAlertIfNeeded(for: entry.id)
    }

    private func presentInsufficientStockAlertIfNeeded(for entryID: UUID) {
        let shortIngredients = appState.insufficientStockIngredients(for: entryID)
        guard !shortIngredients.isEmpty else { return }
        insufficientStockMessage = "Not enough pantry stock for \(shortIngredients.joined(separator: ", ")) — clamped to zero."
        isShowingInsufficientStockAlert = true
    }

    // MARK: - Row UI

    /// A plain `HStack` + `.contentShape(Rectangle())` + `.onTapGesture` for
    /// the row's primary action (push `MealDetailView`), with the planned
    /// row's tick-off control kept a separate `.buttonStyle(.plain)`
    /// `Button` — the nested-tappable-controls-safe shape this codebase
    /// already established in `PackageVariantsView.row(for:)` and reused by
    /// UX-3, rather than nesting a `Button` inside a `NavigationLink`.
    private func entryRow(_ entry: MealEntry) -> some View {
        let completeness = MealStore.completeness(for: entry.ingredients)
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        let prefix = completeness.isComplete ? "" : "≥ "
        let shortfalls = entry.status == .planned ? appState.stockShortfalls(for: entry.id) : []

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                Text("\(entry.ingredients.count) ingredient\(entry.ingredients.count == 1 ? "" : "s") · \(prefix)\(kcal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(shortfalls) { shortfall in
                    Label(
                        "Needs \(formattedAmount(shortfall.needed)) \(shortfall.unitLabel) \(shortfall.productName), have \(formattedAmount(shortfall.available))",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            if entry.status == .planned {
                Button {
                    tickOff(entry)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .tint(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, entry.status == .planned ? 8 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(entry.status == .planned ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntryID = entry.id
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Slot display

    private func displayName(for slot: MealSlot) -> String {
        switch slot {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    private func icon(for slot: MealSlot) -> String {
        switch slot {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
        }
    }
}
