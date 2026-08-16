import Foundation
import Observation
@_exported import FoodFoundation

/// App-wide state. The app uses the `shared` singleton via
/// `@Environment(AppState.self)`; `init()` is public (rather than the
/// usual private-singleton pattern) so tests can construct isolated
/// instances instead of sharing global state across test cases.
///
/// **Mid-restructuring (docs/tasks/epic-1-package-architecture):** the
/// pantry logic that used to live directly on this class has moved to
/// `PantryKit.PantryStore` (see package-architecture.md §3.3). This class
/// is being reduced to a composition root holding `pantry: PantryStore`
/// alongside a future `meals: MealStore` — that wiring, and the app-wide
/// view call-site rename it requires, lands in PA-5. Until then this is
/// intentionally an empty shell and the app target will not build.
@Observable
public class AppState {
    public static let shared = AppState()

    public init() {}
}
