import Foundation

/// A named, reusable composition — "Morning Toast = 2 slices bread + 1
/// egg." Holds no date and no history of its own; `MealStore.instantiate`
/// (or the `logTemplate`/`planTemplate` convenience methods) turns it into
/// a dated `MealEntry` with its ingredients' nutrition resolved fresh
/// (meals-feature-design.md §4.1) — that's what makes a template a live
/// recipe rather than a record.
///
/// Created either explicitly (a "New Meal" editor, future UI) or promoted
/// from something already logged ("Remember this meal?", §7) — both land
/// here the same way, as a plain value.
public struct MealTemplate: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    /// The slot a new entry defaults to when this template is logged
    /// without an explicit override — e.g. a template built around eggs and
    /// toast defaults to `.breakfast`.
    public var defaultSlot: MealSlot
    public var ingredients: [TemplateIngredient]

    public init(id: UUID = UUID(), name: String, defaultSlot: MealSlot, ingredients: [TemplateIngredient] = []) {
        self.id = id
        self.name = name
        self.defaultSlot = defaultSlot
        self.ingredients = ingredients
    }
}
