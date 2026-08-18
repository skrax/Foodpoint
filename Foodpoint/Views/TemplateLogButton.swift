import SwiftUI
import FoodpointKit

/// A tappable "log this template right now" control (MK-4,
/// meals-feature-design.md §7's one-tap fast path) — wraps
/// `AppState.logTemplateAndMarkEaten` with its own loading/error state so it
/// can be dropped into both `TemplatesListView`'s rows without duplicating
/// the async call/error-handling glue in more than one place.
///
/// `label` is a `@ViewBuilder` rather than a fixed row layout so the caller
/// controls exactly how the tappable area looks (a full list row today;
/// nothing stops a future caller from using a compact chip instead) — this
/// view only owns the tap behavior and its loading/error state, never the
/// visual shape.
struct TemplateLogButton<Label: View>: View {
    let template: MealTemplate
    @ViewBuilder var label: () -> Label

    @Environment(AppState.self) private var appState
    @State private var isLogging = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        Button {
            log()
        } label: {
            if isLogging {
                HStack {
                    ProgressView()
                    Spacer()
                }
            } else {
                label()
            }
        }
        .buttonStyle(.plain)
        .disabled(isLogging)
        .alert("Couldn't Log Meal", isPresented: $isShowingError, presenting: errorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    /// Instantiates `template` fresh and logs it via
    /// `AppState.logTemplateAndMarkEaten` — the same plan-then-`markMealEaten`
    /// orchestration a manually composed meal goes through
    /// (`MealsView.logAndMarkEaten`), so a one-tap template log decrements
    /// pantry stock identically to a manual one, not through a separate,
    /// potentially-diverging code path.
    private func log() {
        isLogging = true
        Task {
            do {
                _ = try await appState.logTemplateAndMarkEaten(template)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isLogging = false
        }
    }
}
