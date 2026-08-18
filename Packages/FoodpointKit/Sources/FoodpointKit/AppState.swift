import Foundation
import Observation
@_exported import FoodFoundation
@_exported import PantryKit
@_exported import MealKit

/// App-wide state: the composition root over each domain's own store. The
/// app uses the `shared` singleton via `@Environment(AppState.self)`.
///
/// This class deliberately holds no forwarding properties of its own —
/// views reach into `appState.pantry.*`/`appState.meals.*` directly rather
/// than this class re-declaring `PantryStore`'s/`MealStore`'s entire
/// surface, which would just be boilerplate duplicating an API that already
/// exists one property away (see package-architecture.md §3.5). `pantry`
/// and `meals` are deliberately peers with no reference to one another
/// (`PantryKit` and `MealKit` don't depend on each other either) — any
/// cross-domain orchestration between the two lives in an `extension
/// AppState` instead (see `markMealEaten`/`undoMealEaten` below, MK-3),
/// since this is the one place allowed to know both domains exist.
@Observable
public class AppState {
    public static let shared = AppState()

    public let pantry = PantryStore()
    public let meals = MealStore()

    /// Tracks, per `LoggedIngredient.id`, how much `pantry.consume` actually
    /// took the last time that ingredient's entry was marked eaten — which
    /// can be less than the ingredient's own logged `amount` if there wasn't
    /// enough pantry stock (meals-feature-design.md §4.4's clamp-to-zero
    /// case). `undoMealEaten` needs this to restore *exactly* what was
    /// decremented, not naively the full logged amount, and
    /// `insufficientStockIngredients(for:)` needs it to know which
    /// ingredients came up short. `MealEntry`/`LoggedIngredient` are frozen
    /// snapshots (meals-feature-design.md §4.3) with no field of their own
    /// to record this transient fact, so it lives here instead, in the one
    /// place that orchestrates both stores. Not `@Observable`-tracked UI
    /// state — just bookkeeping between a `markMealEaten` and its matching
    /// `undoMealEaten` — so it's `@ObservationIgnored`.
    @ObservationIgnored
    private var consumedAmounts: [UUID: Double] = [:]

    public init() {}
}

// MARK: - Meal <-> pantry orchestration (MK-3, package-architecture.md §3.5)

extension AppState {
    /// Ticks a planned entry off as eaten and applies its pantry side
    /// effects — package-architecture.md §3.5's orchestration sketch.
    /// `meals.markEaten` only transitions the entry's state and hands back
    /// what changed; decrementing `pantry` for the right ingredients happens
    /// here, since `MealKit` itself never touches inventory (by design —
    /// see `MealStore.markEaten`'s doc comment).
    ///
    /// For each ingredient with `usesFromPantry` on, decrements `pantry` by
    /// `ingredient.amount` via `PantryStore.consume`, which clamps to zero
    /// rather than going negative if stock is insufficient
    /// (meals-feature-design.md §4.4) — logging never blocks or throws on
    /// this. The actually-consumed amount (which may be less than
    /// `ingredient.amount` if clamped) is remembered in `consumedAmounts` so
    /// `undoMealEaten` can reverse precisely this call, and so
    /// `insufficientStockIngredients(for:)` can report the shortfall for a
    /// soft inline note in the UI. Ingredients with the toggle off are
    /// skipped entirely — they never touch `pantry` (also covers take-out/
    /// eaten-elsewhere food, meals-feature-design.md §4.4).
    ///
    /// No-op, including no pantry mutation, if `entryID` doesn't exist or
    /// isn't currently `.planned` — matches `MealStore.markEaten`'s own
    /// contract. Returns the finalized entry so a caller can act on it
    /// further (e.g. checking `insufficientStockIngredients(for:)` right
    /// after).
    @discardableResult
    public func markMealEaten(_ entryID: UUID) -> MealEntry? {
        guard let entry = meals.markEaten(entryID) else { return nil }
        for ingredient in entry.ingredients where ingredient.usesFromPantry {
            let consumed = pantry.consume(barcode: ingredient.barcode, amount: ingredient.amount)
            consumedAmounts[ingredient.id] = consumed
        }
        return entry
    }

    /// Reverses `markMealEaten`: moves the entry back to `.planned` via
    /// `meals.undo`, then restores pantry stock for each `usesFromPantry`
    /// ingredient by exactly the amount `markMealEaten` actually decremented
    /// (from `consumedAmounts`) — not naively `ingredient.amount`, since
    /// those can differ when `consume` clamped due to insufficient stock.
    /// Falls back to `ingredient.amount` if this entry was never marked
    /// eaten through this `AppState` instance (no bookkeeping to consult),
    /// which is the safest assumption — restoring the full logged amount
    /// rather than nothing.
    ///
    /// Uses `PantryStore.restore` rather than a raw quantity bump so the
    /// package-architecture.md §4.3 edge case — a meal that fully depleted
    /// (and thus deleted) a pantry item — recreates that item instead of
    /// silently doing nothing to a barcode with no `FoodItem` left to bump.
    ///
    /// No-op if `entryID` doesn't exist or isn't currently `.eaten` (matches
    /// `MealStore.undo`'s own contract). Returns the reverted entry.
    @discardableResult
    public func undoMealEaten(_ entryID: UUID) -> MealEntry? {
        guard let entry = meals.undo(entryID) else { return nil }
        for ingredient in entry.ingredients where ingredient.usesFromPantry {
            let restoredAmount = consumedAmounts.removeValue(forKey: ingredient.id) ?? ingredient.amount
            guard restoredAmount > 0 else { continue }
            let product = Product(
                id: ingredient.barcode,
                name: ingredient.productName,
                brand: ingredient.productBrand,
                imageURL: ingredient.imageURL,
                nutriScoreGrade: nil,
                categoriesTags: [],
                nutrition: ingredient.impliedNutritionPer100g
            )
            pantry.restore(product: product, unit: ingredient.impliedUnit, amount: restoredAmount)
        }
        return entry
    }

    /// Which `usesFromPantry` ingredients on `entryID` came up short against
    /// pantry stock the last time it was marked eaten through this
    /// `AppState` — i.e. `PantryStore.consume` clamped rather than fully
    /// covering `ingredient.amount`. Empty means nothing clamped (including
    /// "this entry was never marked eaten here"). Purely a read of
    /// `consumedAmounts`, the same bookkeeping `undoMealEaten` uses — never
    /// mutates anything — so the UI can call it right after
    /// `markMealEaten(_:)` to surface meals-feature-design.md §4.4's "soft
    /// inline note" without `PantryStore.consume`'s return value having been
    /// threaded through the call site by hand. Returns each ingredient's
    /// `productName` (falling back to its barcode if unnamed).
    public func insufficientStockIngredients(for entryID: UUID) -> [String] {
        guard let entry = meals.entries.first(where: { $0.id == entryID }) else { return [] }
        return entry.ingredients
            .filter { $0.usesFromPantry && (consumedAmounts[$0.id] ?? $0.amount) < $0.amount }
            .map { $0.productName ?? $0.barcode }
    }

    /// The soft "needs 6 eggs, you have 4" signal (meals-feature-design.md
    /// §5, §12 #5) for a still-`.planned` entry — the day timeline's
    /// per-entry insufficient-stock note (MK-5). Wires `MealStore`'s pure
    /// `stockShortfalls(for:availableQuantity:)` comparison to `pantry.items`,
    /// since this is the one place both stores are visible
    /// (package-architecture.md §3.5) and `MealKit` itself can't read
    /// `PantryKit` directly.
    ///
    /// Computed fresh from current `pantry` quantities every call — it never
    /// reserves, holds, or otherwise mutates any quantity, matching §12 #5's
    /// "no reservation" decision: a plan can sit for weeks and this will
    /// simply reflect however the pantry looks *right now*, each time it's
    /// asked. Empty for an unknown `entryID` or one that's already `.eaten`
    /// (its pantry effect, if any, already happened — nothing left to warn
    /// about).
    public func stockShortfalls(for entryID: UUID) -> [MealStore.StockShortfall] {
        guard let entry = meals.entries.first(where: { $0.id == entryID }), entry.status == .planned else { return [] }
        return MealStore.stockShortfalls(for: entry.ingredients) { barcode in
            pantry.items.first(where: { $0.id == barcode })?.quantity
        }
    }

    /// One-tap template logging (MK-4, meals-feature-design.md §7): the
    /// orchestration-aware counterpart to `MealStore.logTemplate` — that
    /// method alone can't decrement pantry stock, since `MealKit` never
    /// touches inventory itself (`MealStore.markEaten`'s own doc comment).
    /// Instead this follows the exact two-step path ad-hoc logging already
    /// uses (`DayTimelineView.addEntry`: `meals.plan` then
    /// `markMealEaten(_:)`), just fed by `meals.instantiate(template)`
    /// instead of a composer's output — so a template tap behaves
    /// identically to a manually composed and logged meal, pantry
    /// orchestration included, not a separate code path that could drift
    /// from it.
    ///
    /// `date`/`slot` default to today/the template's own `defaultSlot`,
    /// matching `MealStore.logTemplate`'s own defaults. Rethrows whatever
    /// `instantiate` throws (a `ProductResolver` failure — e.g. the network
    /// call for one of the template's ingredients failed) without planning
    /// or logging anything in that case.
    ///
    /// Not covered by `FoodpointKitTests` the way `markMealEaten`/
    /// `undoMealEaten` are: `AppState.meals` has no `productResolver`
    /// injection seam of its own (unlike a directly-constructed `MealStore`
    /// in `MealKitTests`), so exercising this end-to-end here would require
    /// a live network call, which this repo's tests never make. The pieces
    /// it composes — `meals.instantiate`/`logTemplate` (`MealKitTests`'
    /// `TemplateInstantiationTests`/`TemplatePromotionTests`) and
    /// `markMealEaten`'s pantry decrement (this package's
    /// `MealPantryOrchestrationTests`) — are each already covered
    /// separately; this method is exercised end-to-end by manual
    /// verification instead.
    @discardableResult
    public func logTemplateAndMarkEaten(_ template: MealTemplate, date: Date = Date(), slot: MealSlot? = nil) async throws -> MealEntry? {
        let ingredients = try await meals.instantiate(template)
        let planned = meals.plan(name: template.name, date: date, slot: slot ?? template.defaultSlot, ingredients: ingredients, templateID: template.id)
        return markMealEaten(planned.id)
    }
}
