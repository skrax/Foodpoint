import Foundation
import FoodFoundation

/// One frozen ingredient line item on a `MealEntry`. The key distinction
/// from `TemplateIngredient`: once a meal is eaten, its nutrition must stop
/// moving (meals-feature-design.md §4.3). Logging an ingredient — whether
/// typed in directly or instantiated from a template — calls
/// `FoodFoundation.ProductLookup.fetch` once (`MealStore.resolveIngredient`/
/// `.instantiate`) and freezes everything it returns onto this record:
/// `productName`, `productBrand`, `gramsResolved`, and `nutritionSnapshot`.
/// If the user later corrects the product's nutrition data or renames its
/// unit, last month's totals must not silently change underneath them —
/// **pantry state is live, meal history is frozen.**
///
/// Planned entries use this same shape but are expected to be refreshed if
/// edited before their date arrives, since they haven't happened yet and
/// should reflect current data up to that point — `MealStore` doesn't
/// auto-refresh them; that's a future UI concern.
public struct LoggedIngredient: Identifiable, Codable, Equatable {
    public let id: UUID
    /// The product's barcode — Open Food Facts' `code`.
    public var barcode: String
    public var productName: String?
    public var productBrand: String?
    public var imageURL: URL?
    /// Amount in `unitLabel`'s unit, e.g. `2` "slices" or `150` "g" —
    /// frozen at logging time.
    public var amount: Double
    /// The unit label captured at logging time (e.g. "slices", "g"). Frozen
    /// alongside everything else so it can't drift from what was actually
    /// logged even if this ingredient's unit configuration changes later.
    public var unitLabel: String
    /// `amount` converted to grams at logging time
    /// (`amount × unit.gramsPerUnit`, meals-feature-design.md §4.6) — the
    /// basis `nutritionSnapshot` was scaled from, frozen for the same
    /// reason as everything else here.
    public var gramsResolved: Double
    /// Nutrition for `gramsResolved` grams of this product, frozen at
    /// logging time. `nil` when the product had no usable nutrition data at
    /// all (`Nutrition.isEffectivelyEmpty`) — aggregation (§8.2) must report
    /// this as a completeness gap in the total, never silently treat it as
    /// zero.
    public var nutritionSnapshot: Nutrition?
    /// Whether eating this ingredient decremented pantry stock. Seeded from
    /// the source `TemplateIngredient`'s default when instantiated, but
    /// independently editable per logged instance from then on
    /// (meals-feature-design.md §4.4) — consumption/nutrition tracking (§8,
    /// §9) counts this ingredient regardless of this flag; it only gates
    /// the pantry-quantity side effect.
    public var usesFromPantry: Bool

    public init(
        id: UUID = UUID(),
        barcode: String,
        productName: String?,
        productBrand: String?,
        imageURL: URL?,
        amount: Double,
        unitLabel: String,
        gramsResolved: Double,
        nutritionSnapshot: Nutrition?,
        usesFromPantry: Bool = true
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.productBrand = productBrand
        self.imageURL = imageURL
        self.amount = amount
        self.unitLabel = unitLabel
        self.gramsResolved = gramsResolved
        self.nutritionSnapshot = nutritionSnapshot
        self.usesFromPantry = usesFromPantry
    }
}

extension LoggedIngredient {
    /// Reconstructs the `ProductUnit` this ingredient was logged with, from
    /// `unitLabel`/`amount`/`gramsResolved` — `LoggedIngredient` doesn't
    /// store a full `ProductUnit` (only the frozen `unitLabel`), but the
    /// "from history" ingredient source (meals-feature-design.md §6.1 #2)
    /// needs one so the composition editor (MK-2) can let the amount be
    /// edited without a network call. `gramsPerUnit` is `amount`'s implied
    /// grams-per-single-unit ratio (`gramsResolved / amount`); `nil` when
    /// `amount` is zero, since the ratio is undefined.
    ///
    /// `quantityPerPackage` is set to this ingredient's own `amount` purely
    /// so the value round-trips sensibly if inspected — `MealStore.makeIngredient`
    /// only ever reads `gramsPerUnit`/`label` off a `ProductUnit`, never
    /// `quantityPerPackage`.
    public var impliedUnit: ProductUnit {
        ProductUnit(
            label: unitLabel,
            quantityPerPackage: amount,
            gramsPerUnit: amount > 0 ? gramsResolved / amount : nil
        )
    }

    /// Reconstructs this ingredient's nutrition per 100g by inverting the
    /// `scaled(by:)` call `MealStore.makeIngredient` applied at logging
    /// time (`nutritionSnapshot = raw.scaled(by: gramsResolved / 100)`) —
    /// lets the "from history" source (§6.1 #2) recompute a total for a
    /// different amount without re-fetching from Open Food Facts. `nil`
    /// when there was no nutrition data to begin with, or `gramsResolved`
    /// is zero (the inverse scale factor would be undefined).
    public var impliedNutritionPer100g: Nutrition? {
        guard let nutritionSnapshot, gramsResolved > 0 else { return nil }
        return nutritionSnapshot.scaled(by: 100 / gramsResolved)
    }
}
