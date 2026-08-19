import SwiftUI
import FoodpointKit

/// A tappable "add this template to today" control (MK-4, restructured for
/// affordance clarity by FX-7) — wraps `AppState.logTemplateAndMarkEaten`
/// with its own loading/error state so it can be dropped into
/// `TemplatesListView`'s rows without duplicating the async call/
/// error-handling glue in more than one place.
///
/// **FX-7**: this used to make the entire row a `Button` showing a
/// `bolt.fill` icon — user testing found nothing about "a lightning bolt"
/// communicated "logs this to today, right now." It's now a trailing "+"
/// `Menu` listing every `MealSlot`, deliberately mirroring
/// `DayTimelineView.addMealMenu` exactly (same "+" glyph, same
/// tap-then-pick-a-slot shape) so "+" means the same thing everywhere in
/// the Meals tab rather than introducing a one-off icon/gesture just for
/// templates. `template.defaultSlot` is listed first and labeled "(Usual)"
/// so the common case is still a fast top-of-menu pick, but any slot is
/// selectable — previously logging always silently used `template.defaultSlot`
/// with no way to override it from this screen.
///
/// `label` is a `@ViewBuilder` for the row's *descriptive* content only
/// (name, slot/ingredient caption, etc.) — this view appends its own
/// trailing "+" menu after whatever `label` renders, and owns the tap
/// behavior, loading state, and error alert itself; the caller no longer
/// needs to render its own log-affordance icon.
struct TemplateLogButton<Label: View>: View {
    let template: MealTemplate
    @ViewBuilder var label: () -> Label

    @Environment(AppState.self) private var appState
    @State private var isLogging = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        HStack {
            label()
            Spacer(minLength: 8)
            if isLogging {
                ProgressView()
            } else {
                addMenu
            }
        }
        .alert("Couldn't Log Meal", isPresented: $isShowingError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    /// The "+" affordance itself — same shape as
    /// `DayTimelineView.addMealMenu`: tap "+", pick a `MealSlot`, and the
    /// template is logged to today at that slot via `log(slot:)` below.
    /// `.disabled` while a log is in flight so a slow network call can't be
    /// triggered twice concurrently from the same row.
    private var addMenu: some View {
        Menu {
            ForEach(orderedSlots) { slot in
                Button {
                    log(slot: slot)
                } label: {
                    // `SwiftUI.Label` explicitly — this type's own generic
                    // parameter is also named `Label` (the caller's row
                    // content), which would otherwise shadow it here.
                    SwiftUI.Label(
                        slot == template.defaultSlot ? "\(displayName(for: slot)) (Usual)" : displayName(for: slot),
                        systemImage: icon(for: slot)
                    )
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .disabled(isLogging)
        .accessibilityLabel("Add \(template.name) to Today")
    }

    /// `template.defaultSlot` first — the fast path, so a first-time user
    /// can just tap "+" then the top item — followed by the remaining slots
    /// in `MealSlot`'s fixed order.
    private var orderedSlots: [MealSlot] {
        [template.defaultSlot] + MealSlot.allCases.filter { $0 != template.defaultSlot }
    }

    /// Mirrors `DayTimelineView.displayName(for:)` — kept as its own copy
    /// rather than shared, same as that view keeps its own `icon(for:)`
    /// pair; both are small, stable switch statements over a fixed enum.
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

    /// Instantiates `template` fresh and logs it to `slot` via
    /// `AppState.logTemplateAndMarkEaten` — the same plan-then-`markMealEaten`
    /// orchestration a manually composed meal goes through
    /// (`DayTimelineView.addEntry`), so a one-tap template log decrements
    /// pantry stock identically to a manual one, not through a separate,
    /// potentially-diverging code path. Unchanged by FX-7 — only the
    /// trigger UI above changed, not this call or its `slot` parameter.
    private func log(slot: MealSlot) {
        isLogging = true
        Task {
            do {
                _ = try await appState.logTemplateAndMarkEaten(template, slot: slot)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isLogging = false
        }
    }
}
