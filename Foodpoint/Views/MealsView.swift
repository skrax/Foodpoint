import SwiftUI
import FoodpointKit

/// "Meals" tab root. As of MK-5 this is the real Meals tab home
/// meals-feature-design.md §10 calls for — a day timeline, opening on
/// today — not the flat-list placeholder MK-2/MK-3 shipped ahead of it.
/// This view itself is now deliberately thin: it owns just the tab's
/// `NavigationStack` shell and hosts `DayTimelineView`, which is where the
/// actual timeline (date navigation, slot grouping, planned/eaten rows,
/// tick-off, undo, the insufficient-stock signal, templates access, and the
/// "Remember this meal?" prompt) lives. Splitting it out this way, rather
/// than growing this file in place, keeps "the new Meals tab home screen" as
/// one clearly-scoped file rather than an ever-larger `MealsView`.
struct MealsView: View {
    var body: some View {
        NavigationStack {
            DayTimelineView()
        }
    }
}
