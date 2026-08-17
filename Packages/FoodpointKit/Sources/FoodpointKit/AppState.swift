import Foundation
import Observation
@_exported import FoodFoundation
@_exported import PantryKit
@_exported import MealKit

/// App-wide state: the composition root over each domain's own store. The
/// app uses the `shared` singleton via `@Environment(AppState.self)`.
///
/// This class deliberately holds no logic or forwarding properties of its
/// own — views reach into `appState.pantry.*`/`appState.meals.*` directly
/// rather than this class re-declaring `PantryStore`'s/`MealStore`'s entire
/// surface, which would just be boilerplate duplicating an API that already
/// exists one property away (see package-architecture.md §3.5). `pantry`
/// and `meals` are deliberately peers with no reference to one another
/// (`PantryKit` and `MealKit` don't depend on each other either) — any
/// cross-domain orchestration between the two (e.g. logging a meal
/// decrementing pantry stock) belongs here, since this is the one place
/// allowed to know both domains exist. That orchestration doesn't exist yet
/// (MK-1 only wires `meals` in) — it lands in MK-3.
@Observable
public class AppState {
    public static let shared = AppState()

    public let pantry = PantryStore()
    public let meals = MealStore()

    public init() {}
}
