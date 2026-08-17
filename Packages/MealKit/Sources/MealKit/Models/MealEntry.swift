import Foundation

/// One row on the meal timeline — a planned or eaten occurrence, carrying a
/// date, a slot, a status, and its own copy of the ingredients
/// (`LoggedIngredient`, frozen once `.eaten` — meals-feature-design.md
/// §4.2/§4.3). `templateID` optionally remembers which `MealTemplate` this
/// came from, which is what makes "you've eaten this 14 times" possible
/// without string-matching names.
public struct MealEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var date: Date
    public var slot: MealSlot
    public var status: MealStatus
    public var name: String
    /// The `MealTemplate` this entry was instantiated from, if any — `nil`
    /// for an ad-hoc meal composed from scratch.
    public var templateID: UUID?
    public var ingredients: [LoggedIngredient]

    public init(
        id: UUID = UUID(),
        date: Date,
        slot: MealSlot,
        status: MealStatus,
        name: String,
        templateID: UUID? = nil,
        ingredients: [LoggedIngredient] = []
    ) {
        self.id = id
        self.date = date
        self.slot = slot
        self.status = status
        self.name = name
        self.templateID = templateID
        self.ingredients = ingredients
    }
}
