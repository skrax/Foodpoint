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
///
/// **MK-4 additions**, folded in the same way: the same leading toolbar
/// menu also reaches `TemplatesListView` (memorized meals, one-tap
/// logging — see that file for the template CRUD and instantiate-and-log
/// flow itself, kept out of this file by design). After composing and
/// logging an ad-hoc meal **for today** — never for a future/planned
/// entry, which hasn't actually been eaten yet — `addEntry` offers
/// "Remember this meal?" (`RememberMealPrompt.swift`, reusing
/// `ScannerView`'s variant-naming alert shape verbatim) to promote the
/// just-logged ingredients into a `MealTemplate`. If that same log also
/// triggered the insufficient-stock alert, the two are sequenced rather
/// than shown at once: the stock alert's "OK" button is what actually
/// triggers the remember prompt in that case.
///
/// **FX-4 addition**: each row's context menu now offers "Edit Ingredients",
/// opening the same `MealCompositionEditorView` pre-populated via its
/// `initialIngredients` init with the entry's current ingredients (`title:
/// "Edit Meal"`); its `onDone` calls
/// `appState.updateMealIngredients(entry.id, ingredients:)` rather than
/// creating a new entry, so add/remove/amount changes save back onto the
/// same `MealEntry`. That new `AppState` method (`FoodpointKit/AppState.swift`)
/// is what actually reconciles the pantry delta for an `.eaten` entry — this
/// view doesn't need to know the difference between editing a planned vs. an
/// eaten entry, only that this one method handles both correctly.
/// `MealDetailView`'s own toolbar "Edit" button (pushed via this view's row
/// tap) reaches the identical flow — two paths to the same affordance, the
/// same swipe/context-menu-plus-detail-screen-button duplication
/// `TemplatesListView` already has for templates.
///
/// **FX-5 addition**: each row's swipe actions and context menu now also
/// offer "Delete", calling `requestDelete(_:)`. A `.planned` entry deletes
/// immediately (`appState.deleteMeal(entry.id)`) — planning never touched
/// pantry stock, so there's no side effect to warn about, the same
/// less-ceremony treatment `TemplatesListView` gives non-destructive-feeling
/// actions. An `.eaten` entry's deletion has a real side effect (it
/// restores pantry stock the log had decremented), so it goes through a
/// confirmation alert first — `entryPendingDeletion`, matching
/// `TemplatesListView`'s own `templatePendingDeletion` confirmation pattern
/// for template deletion. `MealDetailView`'s own toolbar "Delete" button
/// reaches the identical `requestDelete`-shaped flow.
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

    /// The ad-hoc meal's ingredients, held onto from the moment they're
    /// logged (today only — never for a future plan) until the "Remember
    /// this meal?" prompt is dismissed one way or another (MK-4) —
    /// `RememberMealPromptModifier`'s `presenting:` data.
    @State private var pendingRememberIngredients: [LoggedIngredient]?
    @State private var isShowingRememberPrompt = false
    @State private var rememberMealName = ""

    /// The id of the entry currently pushed to `MealDetailView`, or `nil`
    /// when the timeline itself is on screen. Keyed on `id` rather than the
    /// entry itself since `MealEntry` isn't `Hashable`.
    @State private var selectedEntryID: MealEntry.ID?

    /// The entry currently being edited (FX-4) via a row's context menu —
    /// non-`nil` presents `MealCompositionEditorView` pre-populated with its
    /// current ingredients, mirroring `MealDetailView`'s own "Edit" button
    /// (see that view's doc comment) as a second, row-level path to the same
    /// affordance, the same "swipe/context menu here, a top-level button on
    /// the pushed detail screen" duplication `TemplatesListView` already
    /// uses for templates.
    @State private var editingEntry: MealEntry?

    /// The entry pending a confirmation alert before deletion (FX-5) —
    /// non-`nil` only for an `.eaten` entry (a `.planned` one deletes
    /// immediately with no alert, see `requestDelete(_:)`), matching
    /// `TemplatesListView`'s own `templatePendingDeletion` pattern.
    @State private var entryPendingDeletion: MealEntry?

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
                                            Button("Delete", role: .destructive) {
                                                requestDelete(entry)
                                            }
                                            if entry.status == .eaten {
                                                Button("Undo") {
                                                    appState.undoMealEaten(entry.id)
                                                }
                                                .tint(.orange)
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                editingEntry = entry
                                            } label: {
                                                Label("Edit Ingredients", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                requestDelete(entry)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
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
            MealDetailView(entryID: entryID)
        }
        .sheet(item: $editingEntry) { entry in
            MealCompositionEditorView(initialIngredients: entry.ingredients, title: "Edit Meal") { newIngredients in
                guard !newIngredients.isEmpty else { return }
                appState.updateMealIngredients(entry.id, ingredients: newIngredients)
            }
        }
        .alert("Insufficient Stock", isPresented: $isShowingInsufficientStockAlert, presenting: insufficientStockMessage) { _ in
            Button("OK") { presentRememberPromptIfPending() }
        } message: { message in
            Text(message)
        }
        .alert(
            "Delete Meal?",
            isPresented: Binding(get: { entryPendingDeletion != nil }, set: { if !$0 { entryPendingDeletion = nil } }),
            presenting: entryPendingDeletion
        ) { entry in
            Button("Delete", role: .destructive) {
                appState.deleteMeal(entry.id)
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { entryPendingDeletion = nil }
        } message: { entry in
            Text("\"\(entry.name)\" will be removed and its pantry stock restored.")
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
                TemplatesListView()
            } label: {
                Label("Templates", systemImage: "star.fill")
            }
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
    /// (meals-feature-design.md §5), and never offers to remember it as a
    /// template (that's only for something actually eaten). Today or an
    /// earlier day goes through the same two-step plan-then-mark-eaten path
    /// MK-3 built for the original ad-hoc composer, unchanged, including its
    /// soft insufficient-stock note — and then offers "Remember this meal?"
    /// (MK-4), sequenced after the stock alert if both apply.
    private func addEntry(ingredients: [LoggedIngredient], slot: MealSlot) {
        if isFutureDay {
            appState.meals.plan(name: "Planned Meal", date: selectedDate, slot: slot, ingredients: ingredients)
            return
        }

        let planned = appState.meals.plan(name: "Ad-hoc Meal", date: selectedDate, slot: slot, ingredients: ingredients)
        appState.markMealEaten(planned.id)
        pendingRememberIngredients = ingredients
        if !presentInsufficientStockAlertIfNeeded(for: planned.id) {
            isShowingRememberPrompt = true
        }
    }

    // MARK: - Tick-off

    /// Ticks a planned entry off via `appState.markMealEaten(_:)` — the same
    /// MK-3 orchestration a direct log uses (meals-feature-design.md §5) —
    /// then surfaces MK-3's existing soft insufficient-stock note if
    /// anything clamped. Never offers "Remember this meal?" — that's
    /// `addEntry`'s ad-hoc-today path only.
    private func tickOff(_ entry: MealEntry) {
        appState.markMealEaten(entry.id)
        presentInsufficientStockAlertIfNeeded(for: entry.id)
    }

    @discardableResult
    private func presentInsufficientStockAlertIfNeeded(for entryID: UUID) -> Bool {
        let shortIngredients = appState.insufficientStockIngredients(for: entryID)
        guard !shortIngredients.isEmpty else { return false }
        insufficientStockMessage = "Not enough pantry stock for \(shortIngredients.joined(separator: ", ")) — clamped to zero."
        isShowingInsufficientStockAlert = true
        return true
    }

    /// The insufficient-stock alert's "OK" action: if `addEntry` left a
    /// pending remember-prompt behind, show it now that the stock alert is
    /// out of the way (the two are never presented at once).
    private func presentRememberPromptIfPending() {
        guard pendingRememberIngredients != nil else { return }
        isShowingRememberPrompt = true
    }

    // MARK: - Deletion (FX-5)

    /// Deletes `entry` outright via `appState.deleteMeal(_:)` — distinct
    /// from the eaten row's existing swipe-to-undo action, which only
    /// reverts status back to `.planned` and keeps the entry around. A
    /// `.planned` entry has no pantry side effect (planning never touched
    /// stock, meals-feature-design.md §5), so it deletes immediately with no
    /// prompt; an `.eaten` entry's deletion restores pantry stock — a real
    /// side effect worth confirming first, so this instead sets
    /// `entryPendingDeletion` to show the confirmation alert, matching the
    /// judgment call `TemplatesListView` makes for template deletion.
    private func requestDelete(_ entry: MealEntry) {
        if entry.status == .eaten {
            entryPendingDeletion = entry
        } else {
            appState.deleteMeal(entry.id)
        }
    }

    /// "Save Variant" on the remember prompt: promotes `ingredients` into a
    /// new `MealTemplate`, defaulting to today's current slot and an
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
