import Foundation
import Observation
import FoodFoundation

/// Resolves a barcode to a `Product` — the shape of
/// `FoodFoundation.ProductLookup.fetch`. `MealStore` depends on this
/// abstraction rather than calling `ProductLookup.fetch` directly so tests
/// can inject a stub instead of making live network calls, the same way
/// production code gets the real thing via `MealStore`'s default init
/// parameter. `OpenFoodFactsService` (what `ProductLookup.fetch` ultimately
/// calls) has no such seam of its own, so this is solved locally here
/// rather than upstream.
public typealias ProductResolver = @Sendable (String) async throws -> Product

/// Meals state: memorized templates, logged/planned entries, and the
/// aggregation/consumption-stats logic over them. Owned by
/// `FoodpointKit.AppState` as its `meals` property, exactly as `PantryKit`'s
/// `PantryStore` is owned as `pantry` — construct a fresh `MealStore()` in
/// tests rather than sharing a singleton, since it's a single mutable
/// instance and tests may run in any order.
///
/// Has **zero dependency on `PantryKit`**, by design (package-architecture.md
/// §1, §3.4): every ingredient snapshots the product identity/nutrition it
/// needs directly via `ProductResolver` (`FoodFoundation.ProductLookup.fetch`
/// in production), rather than reaching into the pantry or any shared
/// cache. The one ingredient source that genuinely needs pantry data
/// ("pick something already in my pantry") is composed one layer up, in
/// `FoodpointKit`, which is the only place allowed to know both stores
/// exist (package-architecture.md §3.5) — not implemented here (MK-3).
@Observable
public final class MealStore {
    /// How new/instantiated ingredients resolve a barcode to a `Product`.
    /// Defaults to the real `FoodFoundation.ProductLookup.fetch`; tests pass
    /// a stub. Not itself `@Observable`-tracked — it's fixed configuration,
    /// not mutable state.
    @ObservationIgnored
    private let productResolver: ProductResolver

    public var templates: [MealTemplate] = []
    public var entries: [MealEntry] = []

    public init(productResolver: @escaping ProductResolver = { barcode in try await ProductLookup.fetch(barcode: barcode) }) {
        self.productResolver = productResolver
    }

    // MARK: - Template CRUD

    public func addTemplate(_ template: MealTemplate) {
        templates.append(template)
    }

    /// Replaces an existing template (matched by `id`) in place. A no-op if
    /// `template.id` isn't known.
    public func updateTemplate(_ template: MealTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index] = template
    }

    public func removeTemplate(_ templateID: UUID) {
        templates.removeAll { $0.id == templateID }
    }

    // MARK: - Ingredient acquisition (immediate snapshot)

    /// Pure, synchronous core of `resolveIngredient`/`instantiate`: given a
    /// product's identity/nutrition (already fetched, from wherever) plus an
    /// amount and unit, computes the frozen `LoggedIngredient` fields —
    /// `grams = amount × unit.gramsPerUnit` (meals-feature-design.md §4.6),
    /// and `nutritionSnapshot` scaled from `nutritionPer100g`, or `nil` when
    /// there's no usable data (`Nutrition.isEffectivelyEmpty`) rather than a
    /// silent zero.
    ///
    /// Extracted as its own testable, network-free function (rather than
    /// inlined separately in `resolveIngredient` and `instantiate`, which
    /// now both call this) specifically so the composition editor (MK-2,
    /// `Foodpoint/Views/MealCompositionEditorView.swift`) can rebuild a
    /// `LoggedIngredient` for a locally-edited amount — e.g. the user
    /// changing "2 slices" to "3 slices" on a row already added — without
    /// re-fetching from Open Food Facts. Pair with
    /// `LoggedIngredient.impliedUnit`/`.impliedNutritionPer100g` to
    /// round-trip an already-resolved ingredient back through this function
    /// for a new amount.
    public static func makeIngredient(
        barcode: String,
        productName: String?,
        productBrand: String?,
        imageURL: URL?,
        nutritionPer100g: Nutrition?,
        amount: Double,
        unit: ProductUnit,
        usesFromPantry: Bool = true
    ) -> LoggedIngredient {
        let grams = amount * (unit.gramsPerUnit ?? 1)
        let nutrition = nutritionPer100g.flatMap { $0.isEffectivelyEmpty ? nil : $0.scaled(by: grams / 100) }
        return LoggedIngredient(
            barcode: barcode,
            productName: productName,
            productBrand: productBrand,
            imageURL: imageURL,
            amount: amount,
            unitLabel: unit.label,
            gramsResolved: grams,
            nutritionSnapshot: nutrition,
            usesFromPantry: usesFromPantry
        )
    }

    /// Resolves `barcode` and snapshots everything a `LoggedIngredient`
    /// needs onto it immediately — one `productResolver` call, right now,
    /// not deferred. See `makeIngredient` for the grams/nutrition
    /// computation itself, shared with `instantiate`.
    ///
    /// Once this returns, the ingredient is fully self-sufficient: browsing
    /// it later (a "recently used" list, a template, a logged entry) reads
    /// straight off its own fields and needs no further network call.
    public func resolveIngredient(
        barcode: String,
        amount: Double,
        unit: ProductUnit,
        usesFromPantry: Bool = true
    ) async throws -> LoggedIngredient {
        let product = try await productResolver(barcode)
        return Self.makeIngredient(
            barcode: barcode,
            productName: product.name,
            productBrand: product.brand,
            imageURL: product.imageURL,
            nutritionPer100g: product.nutrition,
            amount: amount,
            unit: unit,
            usesFromPantry: usesFromPantry
        )
    }

    /// Same immediate-snapshot behavior as `resolveIngredient`, but for a
    /// `TemplateIngredient` — deliberately excludes nutrition
    /// (meals-feature-design.md §4.1), since a template resolves that fresh
    /// every time it's instantiated instead.
    public func resolveTemplateIngredient(
        barcode: String,
        amount: Double,
        unit: ProductUnit,
        usesFromPantry: Bool = true
    ) async throws -> TemplateIngredient {
        let product = try await productResolver(barcode)
        return TemplateIngredient(
            barcode: barcode,
            productName: product.name,
            productBrand: product.brand,
            imageURL: product.imageURL,
            amount: amount,
            unit: unit,
            usesFromPantry: usesFromPantry
        )
    }

    // MARK: - Template instantiation (fresh nutrition, every time)

    /// Turns a template's ingredients into `LoggedIngredient`s by
    /// re-resolving each barcode fresh via `productResolver` — **not**
    /// reusing any previously cached value, even if this exact template was
    /// instantiated a minute ago (meals-feature-design.md §4.1). This is
    /// what makes a template a live recipe: if the bread's nutrition data
    /// was corrected since the last time "Morning Toast" was logged, this
    /// instantiation reflects it. The cost is one network round trip per
    /// ingredient, same as re-scanning a barcode does today elsewhere in
    /// the app — not a new tradeoff introduced by meals.
    ///
    /// `usesFromPantry` seeds from each `TemplateIngredient`'s own default;
    /// the returned `LoggedIngredient`s are independent copies the caller
    /// is free to edit (including that flag) without affecting the
    /// template itself.
    public func instantiate(_ template: MealTemplate) async throws -> [LoggedIngredient] {
        var ingredients: [LoggedIngredient] = []
        ingredients.reserveCapacity(template.ingredients.count)
        for templateIngredient in template.ingredients {
            let product = try await productResolver(templateIngredient.barcode)
            ingredients.append(
                Self.makeIngredient(
                    barcode: templateIngredient.barcode,
                    productName: product.name,
                    productBrand: product.brand,
                    imageURL: product.imageURL,
                    nutritionPer100g: product.nutrition,
                    amount: templateIngredient.amount,
                    unit: templateIngredient.unit,
                    usesFromPantry: templateIngredient.usesFromPantry
                )
            )
        }
        return ingredients
    }

    // MARK: - Entry CRUD / lifecycle

    /// Logs a meal directly as eaten — the common case (meals-feature-design.md
    /// §5: "log directly (the common case)"). `ingredients` are expected to
    /// already be resolved (via `resolveIngredient` or `instantiate`).
    @discardableResult
    public func logEaten(
        name: String,
        date: Date,
        slot: MealSlot,
        ingredients: [LoggedIngredient],
        templateID: UUID? = nil
    ) -> MealEntry {
        let entry = MealEntry(date: date, slot: slot, status: .eaten, name: name, templateID: templateID, ingredients: ingredients)
        entries.append(entry)
        return entry
    }

    /// Schedules a meal for a future date without touching pantry stock —
    /// only the `.eaten` transition does that (meals-feature-design.md §5).
    @discardableResult
    public func plan(
        name: String,
        date: Date,
        slot: MealSlot,
        ingredients: [LoggedIngredient],
        templateID: UUID? = nil
    ) -> MealEntry {
        let entry = MealEntry(date: date, slot: slot, status: .planned, name: name, templateID: templateID, ingredients: ingredients)
        entries.append(entry)
        return entry
    }

    /// One-tap logging (meals-feature-design.md §7): instantiates `template`
    /// fresh and immediately logs it as eaten today (or `date`, if given).
    @discardableResult
    public func logTemplate(_ template: MealTemplate, date: Date = Date(), slot: MealSlot? = nil) async throws -> MealEntry {
        let ingredients = try await instantiate(template)
        return logEaten(name: template.name, date: date, slot: slot ?? template.defaultSlot, ingredients: ingredients, templateID: template.id)
    }

    /// Instantiates `template` fresh and schedules it as a planned entry.
    @discardableResult
    public func planTemplate(_ template: MealTemplate, date: Date, slot: MealSlot? = nil) async throws -> MealEntry {
        let ingredients = try await instantiate(template)
        return plan(name: template.name, date: date, slot: slot ?? template.defaultSlot, ingredients: ingredients, templateID: template.id)
    }

    /// Ticks off a planned entry as eaten. Returns the finalized entry so
    /// the caller (`FoodpointKit.AppState`, package-architecture.md §3.5)
    /// can act on it — iterate `entry.ingredients` where `usesFromPantry` is
    /// `true` to decrement the right pantry items by `amount`. `MealStore`
    /// itself never touches inventory; it only transitions state and hands
    /// back what changed, keeping this package decoupled from `PantryKit`
    /// (meals-feature-design.md §4.4).
    ///
    /// Returns `nil` if `entryID` doesn't exist or isn't currently
    /// `.planned` (already-eaten entries can't be "eaten" again this way).
    @discardableResult
    public func markEaten(_ entryID: UUID) -> MealEntry? {
        guard let index = entries.firstIndex(where: { $0.id == entryID }), entries[index].status == .planned else { return nil }
        entries[index].status = .eaten
        return entries[index]
    }

    /// Reverses `markEaten`, moving an eaten entry back to planned. Returns
    /// the reverted entry so the caller can restore pantry stock for the
    /// same `usesFromPantry` ingredients `markEaten` would have decremented
    /// — undo matters here specifically because ticking off has an
    /// invisible inventory side effect (meals-feature-design.md §5).
    ///
    /// Returns `nil` if `entryID` doesn't exist or isn't currently `.eaten`.
    @discardableResult
    public func undo(_ entryID: UUID) -> MealEntry? {
        guard let index = entries.firstIndex(where: { $0.id == entryID }), entries[index].status == .eaten else { return nil }
        entries[index].status = .planned
        return entries[index]
    }

    /// Replaces an existing entry (matched by `id`) in place. A no-op if
    /// `entry.id` isn't known.
    public func updateEntry(_ entry: MealEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    /// Deletes an entry and returns it (or `nil` if it didn't exist) so a
    /// caller can restore pantry stock when deleting an `.eaten` entry —
    /// the same "hand back what changed" contract as `markEaten`/`undo`
    /// (meals-feature-design.md §5's "delete (restores pantry, per-
    /// ingredient toggle)" transition).
    @discardableResult
    public func removeEntry(_ entryID: UUID) -> MealEntry? {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return nil }
        return entries.remove(at: index)
    }

    // MARK: - Day / range aggregation

    /// Totals for every nutrient across `.eaten` entries on `date`, with
    /// `.planned` entries totaled separately as a projection — the two are
    /// never summed together (meals-feature-design.md §8.1). Both totals
    /// carry completeness (§8.2).
    public func dayTotal(for date: Date, calendar: Calendar = .current) -> DayNutritionTotal {
        let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let eatenIngredients = dayEntries.filter { $0.status == .eaten }.flatMap(\.ingredients)
        let plannedIngredients = dayEntries.filter { $0.status == .planned }.flatMap(\.ingredients)
        return DayNutritionTotal(
            date: date,
            eaten: Self.completeness(for: eatenIngredients),
            planned: Self.completeness(for: plannedIngredients)
        )
    }

    /// One `dayTotal` per calendar day from `startDate` through `endDate`
    /// inclusive — including days with zero entries, so
    /// `averageEatenPerDay` is a true per-calendar-day average rather than
    /// an average over only the active days (meals-feature-design.md §8.1:
    /// "daily totals, an average, and a simple trend"). `startDate`/`endDate`
    /// are normalized to the start of their day; an empty range (`startDate`
    /// after `endDate`) yields no days and a zero average.
    public func rangeSummary(from startDate: Date, to endDate: Date, calendar: Calendar = .current) -> RangeNutritionSummary {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return RangeNutritionSummary(days: [], averageEatenPerDay: .zero) }

        var days: [DayNutritionTotal] = []
        var cursor = start
        while cursor <= end {
            days.append(dayTotal(for: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        let total = days.reduce(Nutrition.zero) { $0 + $1.eaten.total }
        let average = total / Double(days.count)
        return RangeNutritionSummary(days: days, averageEatenPerDay: average)
    }

    /// Sums `nutritionSnapshot` across `ingredients`, reporting how many had
    /// none rather than silently treating a missing one as zero
    /// (meals-feature-design.md §8.2). Used internally by `dayTotal`, and
    /// public so the composition editor's (MK-2) running footer can compute
    /// the same completeness signal live, over whatever's currently in the
    /// editor, without duplicating this logic or requiring a `MealEntry` to
    /// exist yet.
    public static func completeness(for ingredients: [LoggedIngredient]) -> NutritionCompleteness {
        var total = Nutrition.zero
        var missing = 0
        for ingredient in ingredients {
            if let nutrition = ingredient.nutritionSnapshot {
                total = total + nutrition
            } else {
                missing += 1
            }
        }
        return NutritionCompleteness(total: total, consideredCount: ingredients.count, missingCount: missing)
    }

    // MARK: - Ingredient history (no network call)

    /// Distinct ingredients this store has ever logged or planned, one row
    /// per barcode, most-recently-used entry first — the data behind the
    /// "from history" ingredient source (meals-feature-design.md §6.1 #2).
    /// Reads straight off already-snapshotted `LoggedIngredient` fields
    /// across `entries`, so — unlike scan/search — this never makes a
    /// network call; that's the entire point of this acquisition source.
    public func recentlyUsedIngredients() -> [LoggedIngredient] {
        var seenBarcodes = Set<String>()
        var result: [LoggedIngredient] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            for ingredient in entry.ingredients {
                guard seenBarcodes.insert(ingredient.barcode).inserted else { continue }
                result.append(ingredient)
            }
        }
        return result
    }

    /// The `ProductUnit` most recently used for `barcode` across this
    /// store's own history — a logged ingredient's `impliedUnit` if one
    /// exists (most recent entry first), else a template ingredient's
    /// `unit` if the barcode only appears in a template, else `nil`.
    ///
    /// `nil` means this barcode has never been used as a MealKit ingredient
    /// before, which is exactly the composition editor's (MK-2) signal to
    /// prompt its minimal per-ingredient unit setup
    /// (meals-feature-design.md §6.3) rather than silently guessing — and
    /// deliberately never falls back to PantryKit's own unit config for the
    /// same barcode, even if one exists, per this package's zero-dependency
    /// rule on `PantryKit`.
    public func lastKnownUnit(forBarcode barcode: String) -> ProductUnit? {
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            if let ingredient = entry.ingredients.first(where: { $0.barcode == barcode }) {
                return ingredient.impliedUnit
            }
        }
        return templates.flatMap(\.ingredients).first(where: { $0.barcode == barcode })?.unit
    }

    // MARK: - Consumption stats

    /// How often and how much of `barcode` was eaten between `startDate`
    /// and `endDate` inclusive — counts every matching ingredient row on
    /// `.eaten` entries regardless of `usesFromPantry` ("did I eat this" is
    /// a different question from "did it come out of my shelf",
    /// meals-feature-design.md §9). `consumptionRatePerDay` divides by the
    /// full number of calendar days in the range, including days with no
    /// entries at all, so a sparse range doesn't read as a higher rate than
    /// it is.
    public func consumptionStats(barcode: String, from startDate: Date, to endDate: Date, calendar: Calendar = .current) -> ConsumptionStats {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let dayCount = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)

        let matches: [(date: Date, ingredient: LoggedIngredient)] = entries
            .filter { $0.status == .eaten }
            .filter { let day = calendar.startOfDay(for: $0.date); return day >= start && day <= end }
            .flatMap { entry in entry.ingredients.filter { $0.barcode == barcode }.map { (entry.date, $0) } }

        let totalAmount = matches.reduce(0) { $0 + $1.ingredient.amount }
        let lastEatenDate = matches.map(\.date).max()

        return ConsumptionStats(
            barcode: barcode,
            timesEaten: matches.count,
            totalAmount: totalAmount,
            lastEatenDate: lastEatenDate,
            consumptionRatePerDay: Double(matches.count) / Double(dayCount)
        )
    }

    /// `consumptionStats` for every barcode that appears on an `.eaten`
    /// entry in the range, most-eaten first — the data behind the Meals
    /// tab's "most consumed" list (meals-feature-design.md §9).
    public func mostConsumed(from startDate: Date, to endDate: Date, calendar: Calendar = .current) -> [ConsumptionStats] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let barcodes = Set(
            entries
                .filter { $0.status == .eaten }
                .filter { let day = calendar.startOfDay(for: $0.date); return day >= start && day <= end }
                .flatMap(\.ingredients)
                .map(\.barcode)
        )
        return barcodes
            .map { consumptionStats(barcode: $0, from: startDate, to: endDate, calendar: calendar) }
            .sorted { $0.timesEaten > $1.timesEaten }
    }
}
