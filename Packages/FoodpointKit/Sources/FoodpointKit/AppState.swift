import Foundation
import Observation
@_exported import FoodFoundation
@_exported import PantryKit

/// App-wide state: the composition root over each domain's own store. The
/// app uses the `shared` singleton via `@Environment(AppState.self)`.
///
/// This class deliberately holds no logic or forwarding properties of its
/// own — views reach into `appState.pantry.*` directly rather than this
/// class re-declaring `PantryStore`'s entire surface, which would just be
/// boilerplate duplicating an API that already exists one property away
/// (see package-architecture.md §3.5). A future `meals: MealStore` will
/// join `pantry` the same way once `MealKit` exists (MK-1), and any
/// cross-domain orchestration between the two (e.g. logging a meal
/// decrementing pantry stock) belongs here — this is the one place
/// allowed to know both domains exist.
@Observable
public class AppState {
    public static let shared = AppState()

    public let pantry = PantryStore()

    public init() {}
}
