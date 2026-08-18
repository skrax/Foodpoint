import Foundation
import FoodFoundation

/// One ingredient row on a `MealTemplate` — a memorized default, not a
/// frozen record. Deliberately carries no nutrition data of its own
/// (meals-feature-design.md §4.1): nutrition is resolved fresh via
/// `FoodFoundation.ProductLookup.fetch` every time the template is turned
/// into a `MealEntry` (`MealStore.instantiate`), so a later correction to a
/// product's nutrition data is reflected the next time the template gets
/// used, not silently ignored.
///
/// `barcode`/`productName`/`productBrand`/`imageURL` are still captured once,
/// at the moment the ingredient is added to the template — via
/// `MealStore.resolveTemplateIngredient`, which calls `ProductLookup.fetch`
/// directly — so the templates list renders instantly and offline, exactly
/// like `LoggedIngredient` does (meals-feature-design.md §4). There is no
/// reference to `PantryKit`'s `FoodItem` here or anywhere else in this
/// package, on purpose.
///
/// `unit` isn't broken out as its own field in the design doc's summary ER
/// diagram, but is required to make `amount` meaningful — the
/// `grams = amount × unit.gramsPerUnit` formula (§4.6) needs it — and to
/// support genuine one-tap logging (§7) without re-asking "weight or
/// count?" on every use. It's established once per ingredient and scoped to
/// that ingredient alone (§6.3: "not written back anywhere PantryKit would
/// see it"), never shared with PantryKit's own per-barcode unit
/// configuration, even for the same barcode.
public struct TemplateIngredient: Identifiable, Codable, Equatable {
    public let id: UUID
    /// The product's barcode — Open Food Facts' `code`, same identity space
    /// `FoodFoundation.Product.id` uses.
    public var barcode: String
    public var productName: String?
    public var productBrand: String?
    public var imageURL: URL?
    /// How much, expressed in `unit.label`'s unit — e.g. `2` "slices" or
    /// `150` "g".
    public var amount: Double
    /// How this ingredient's `amount` is counted (weight or count) and, for
    /// count mode, how many grams one unit represents — scoped to this
    /// ingredient alone, see the type doc above.
    public var unit: ProductUnit
    /// Whether instantiating this ingredient should decrement pantry stock
    /// by default. Seeds — but does not lock — the `LoggedIngredient`
    /// created each time this template is used; the logged copy can be
    /// toggled independently afterward (meals-feature-design.md §4.4).
    public var usesFromPantry: Bool

    public init(
        id: UUID = UUID(),
        barcode: String,
        productName: String?,
        productBrand: String?,
        imageURL: URL?,
        amount: Double,
        unit: ProductUnit,
        usesFromPantry: Bool = true
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.productBrand = productBrand
        self.imageURL = imageURL
        self.amount = amount
        self.unit = unit
        self.usesFromPantry = usesFromPantry
    }
}

extension TemplateIngredient {
    /// Demotes an already-resolved `LoggedIngredient` back into a live-recipe
    /// row — the conversion behind promoting a meal into a `MealTemplate`
    /// (MK-4, meals-feature-design.md §7): both the explicit "New Meal"
    /// editor (whose ingredients come from `MealCompositionEditorView`,
    /// which produces `LoggedIngredient`s) and "Remember this meal?" (which
    /// promotes an already-logged entry's ingredients) go through this.
    ///
    /// Deliberately drops `nutritionSnapshot` — a template resolves
    /// nutrition fresh every time it's instantiated
    /// (`MealStore.instantiate`), never reusing a value frozen at promotion
    /// time. `unit` is reconstructed via `impliedUnit` since
    /// `LoggedIngredient` itself only retains the frozen `unitLabel`/
    /// `gramsResolved`, not a full `ProductUnit`. A fresh `id` is generated
    /// (the default `UUID()`), independent of `logged.id`, since this is a
    /// new row, not the same ingredient occurrence.
    public init(logged: LoggedIngredient) {
        self.init(
            barcode: logged.barcode,
            productName: logged.productName,
            productBrand: logged.productBrand,
            imageURL: logged.imageURL,
            amount: logged.amount,
            unit: logged.impliedUnit,
            usesFromPantry: logged.usesFromPantry
        )
    }
}
