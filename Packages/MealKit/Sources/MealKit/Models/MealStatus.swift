import Foundation

/// Whether a `MealEntry` has actually been eaten, or is only scheduled for
/// later. Planning and logging are the same object in different states
/// (meals-feature-design.md §5) — one timeline, one editor, one aggregation
/// path — rather than two parallel systems. Only the `.planned -> .eaten`
/// transition (`MealStore.markEaten`) touches pantry stock, and only for
/// ingredients with `usesFromPantry` on.
public enum MealStatus: String, Codable, Equatable {
    case planned
    case eaten
}
