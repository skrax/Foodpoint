# Foodpoint

Foodpoint is an iOS pantry inventory tracker. Scan a barcode — or search by
name for something with no barcode to scan, like fresh produce — and the
product's nutrition and brand info (name, brand, category, Nutri-Score,
calories, macros) is pulled live from
[Open Food Facts](https://world.openfoodfacts.org). Saved products live in
one flat, quantity-tracked list.

All of the app's business logic — state, models, and the Open Food Facts
integration — lives in local, UI-agnostic Swift packages, each with its own
unit test suite: `Packages/FoodFoundation` holds the shared domain types
(`Product`, `Nutrition`, `ProductUnit`, `NutritionVariant`, `FoodCategory`)
and product lookup; `Packages/PantryKit` holds the pantry's state and CRUD
logic on top of it (what's saved, how it's counted, its nutrition);
`Packages/MealKit` holds the meals feature's state — templates,
logged/planned entries, nutrition aggregation and consumption stats — as a
fully independent peer of `PantryKit`, sharing nothing with it but
`FoodFoundation`; and `Packages/FoodpointKit` is a thin
composition root tying all of that together as `AppState`, the single
object the app injects into its environment — plus the one place that
knows both `PantryKit` and `MealKit` exist, which is where logging a meal
decrements pantry stock (and undo restores it) lives. The SwiftUI app is a
thin driver on top of all four: views, the camera scanner, and not much
else.

Both ways to add a product — scanning and searching — are reachable from
the Items tab's "•••" menu without leaving the list; the Scan tab itself is
scan-only. "Search by Name" finds candidates by text query against Open Food Facts'
[search-a-licious](https://search.openfoodfacts.org) API — the v2/v3
product API doesn't support free-text search, so this is a distinct
request against a different endpoint, not a variant of the by-barcode
lookup. Picking a result feeds the exact same save flow a barcode scan
would; this covers produce and other unlabeled groceries, not things Open
Food Facts has no listing for at all (a home-cooked dish, still out of
scope). Each result row also has an info button to push a nutrition detail
view for that candidate (e.g. to tell "Banana (Morrisons)" apart from
"Banana (fairtrade)") without committing to it — going back returns to the
same results, query intact.

Each product's quantity can be tracked either as a **count** (e.g. 12
"bars", 15 "slices") or by **weight** (grams) — configured once per
barcode the first time it's scanned, and reusable/editable afterwards.
When a product is tracked by count with a known package weight, nutrition
facts are also shown per count-unit (e.g. "Nutrition per bar (40g)"), not
just Open Food Facts' raw per-100g figures.

Re-scanning a barcode that's already configured shows the package-size
fields again (not just a static summary) so a different-sized package of
the same product can be entered directly — e.g. a 500g bag instead of the
usual 750g, with the slice count recomputed automatically. If that size
isn't already known for this barcode, saving asks for a name (e.g.
"Small") and whether to remember it for next time, or use it just this
once. Named package-size variants can be reviewed, renamed, resized, added,
and deleted from the "Package Sizes" screen, reachable from both the
scanner and an item's detail view. The count label itself (e.g. "slices",
"bars") can also be corrected there at any time — since it applies to
every variant of a barcode, renaming it in one variant's edit form updates
all of them together.

Nutrition works the same way. Some Open Food Facts entries report a
`nutriments` object with every field zero rather than omitting it — the
app treats that as "no data" rather than showing "0 kcal" and offers a
form to enter values by hand instead. Configured values are remembered per
barcode and always shown with a source badge (Open Food Facts vs Custom).
If a later scan finds Open Food Facts data that's new or has changed, a
"Review" prompt shows both options side by side; picking one updates the
default while the other stays available as an alternate, and declining
("Later") still remembers Open Food Facts' new numbers so the same change
isn't asked about again next scan. Manage nutrition variants from the
"Nutrition" screen, reachable the same way as "Package Sizes".

The Meals tab is a day timeline, opening on today: date navigation moves
between days, entries group by slot (breakfast/lunch/dinner/snack) under a
day nutrition summary that keeps "eaten" and "planned" as two separate
figures rather than summing them. Building a meal — whether logging it now
or scheduling it for a future day — uses the same composition editor:
ingredient rows, each with an amount and a "Use from pantry" toggle (on by
default), plus a running nutrition footer that flags when data is
incomplete rather than silently under-counting. Ingredients come from four
sources — the pantry, previously-logged history (no network call),
scanning, or searching by name (both reusing the same camera/search flows
as the Items tab) — and a barcode `MealKit` has never used before gets a
quick, ingredient-scoped weight/count setup prompt, independent of the
pantry's own configuration for that product even if one exists.

Composing a meal for **today** (or an earlier day) logs it immediately —
tapping "Done" decrements pantry stock for every ingredient with "Use from
pantry" on; ingredients with the toggle off (take-out, a friend's
leftovers) are logged for nutrition/history without touching inventory at
all. If the pantry doesn't have enough of something, the decrement clamps
to zero instead of going negative or blocking the log, with a soft
"Insufficient Stock" note naming what came up short. Composing a meal for
a **future** day instead plans it — the entry is created but pantry stock
and today's totals are completely untouched until it's actually ticked
off. Planned entries render with a visible outline to set them apart from
filled eaten rows, each with a prominent checkmark to tick it off (the
same pantry-decrement/insufficient-stock path as logging directly — "the
same object in different states," not a parallel system) and a soft "needs
6 eggs, have 4" note when a plan calls for more than the pantry currently
holds, computed live against current stock without ever reserving or
holding any of it. Swiping an eaten meal (whether logged directly or
ticked off from a plan) offers "Undo," which restores pantry stock by
exactly what was actually taken (not naively the full logged amount, if a
clamp happened) — including re-creating a pantry item that eating the last
of it had fully removed. Editing a product's nutrition later never rewrites
an already-eaten meal's numbers: pantry state is live, meal history is a
frozen snapshot.

This is an early solo prototype — expect rough edges and missing features.

## Stack

- SwiftUI, Swift 5
- `@Observable` (Observation framework) for state — no third-party
  dependencies
- AVFoundation for barcode scanning
- Open Food Facts public API for product lookup, and search-a-licious for
  text search (produce and other unlabeled groceries)
- Swift Testing for the packages' unit tests

## Requirements

- Xcode with an iOS 26.5+ simulator/SDK
- No API keys or accounts needed — Open Food Facts is queried anonymously

## Building & running

Open `Foodpoint.xcodeproj` in Xcode and run the `Foodpoint` scheme on a
simulator or device.

From the command line:

```bash
xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'generic/platform=iOS Simulator' build
```

If `xcodebuild` complains that only the Command Line Tools are selected,
prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
instead of changing the system-wide `xcode-select` path.

Run each package's unit tests directly with Swift Package Manager, without
touching Xcode or a simulator:

```bash
cd Packages/FoodFoundation && swift test
cd Packages/PantryKit && swift test
cd Packages/MealKit && swift test
cd Packages/FoodpointKit && swift test
```

(`FoodpointKit`'s test target covers only its cross-domain orchestration —
`AppState.markMealEaten`/`.undoMealEaten` — not `PantryStore`'s/
`MealStore`'s own logic, which is `PantryKitTests`'/`MealKitTests`' job.)

## Project layout

```
Foodpoint/
  FoodpointApp.swift   App entry point
  ContentView.swift    Root tab bar (Items, Scan, Meals)
  ScannerView.swift    Scan-only acquire -> confirm -> configure-unit ->
                       save flow: barcode -> ProductLookup.fetch ->
                       save/discard. Both the Scan tab's root and, via
                       `entryPoint`, a sheet presentable from elsewhere
                       (ItemsView's "•••" menu, for both its Scan Barcode
                       and Search by Name items) without duplicating this
                       logic
  Views/               SwiftUI views only — no business logic; read/write
                        pantry state via `appState.pantry.*` (or meals
                        state via `appState.meals.*`)
    ItemsView.swift     Items tab; "•••" menu offers Scan Barcode (opens
                        ScannerView directly) and Search by Name (presents
                        ProductSearchView itself, then hands the chosen
                        barcode to ScannerView via a second, sequenced sheet)
    ProductSearchView.swift  Text search sheet; picking a result re-resolves
                              it by barcode through the same path a scan uses
    MealsView.swift     Meals tab root; thin NavigationStack shell hosting
                        DayTimelineView (the tab's actual content)
    DayTimelineView.swift  The Meals tab home: day timeline with date
                        navigation, entries grouped by MealSlot, and a
                        day summary (eaten vs. planned, kept separate). A
                        "+" menu picks a slot then opens
                        MealCompositionEditorView; composing for today
                        logs immediately (plan + appState.markMealEaten,
                        decrementing pantry for "Use from pantry"
                        ingredients, soft note if stock ran short) while
                        composing for a future day only plans it — zero
                        pantry/totals effect until ticked off. Planned
                        rows are outlined, get a checkmark tick-off button
                        (same appState.markMealEaten path as direct
                        logging) and a live "needs 6 eggs, have 4" note
                        (appState.stockShortfalls) computed without
                        reserving stock. Eaten rows keep the swipe-to-undo
                        action (appState.undoMealEaten) that restores
                        pantry stock exactly
    MealCompositionEditorView.swift  Ingredient rows + running nutrition
                        footer with a completeness signal; four ingredient
                        sources (pantry/history/scan/search) behind an
                        "Add Ingredient" menu
    MealIngredientPantryPickerView.swift, MealIngredientHistoryPickerView.swift,
    MealIngredientUnitSetupView.swift  The four sources' picker sheets used
                        by the composition editor
  Scanners/             Barcode scanning (AVFoundation-backed UIViewRepresentable)

Packages/
  FoodpointKit/          Local Swift package: the composition root
    Sources/FoodpointKit/
      AppState.swift      `AppState.shared` holds `pantry: PantryStore` and
                           `meals: MealStore` as independent peers, plus an
                           `extension AppState` with the only cross-domain
                           orchestration in the app: markMealEaten/
                           undoMealEaten (decrement/restore pantry stock for
                           "Use from pantry" ingredients, clamping to zero
                           and re-creating a fully-depleted item on undo),
                           insufficientStockIngredients (for the soft-note
                           UI), and stockShortfalls (the day timeline's live
                           "needs 6 eggs, have 4" signal on a planned entry,
                           computed without reserving any stock)
    Tests/FoodpointKitTests/  Swift Testing unit tests for the orchestration
                              above only

  PantryKit/              Local Swift package: pantry state and CRUD, UI-agnostic
    Sources/PantryKit/
      PantryStore.swift    Items, package-size/nutrition variants, and all
                            their CRUD (what used to be on AppState), plus
                            consume/restore — the meal-driven pantry
                            decrement/undo primitives called only from
                            FoodpointKit's orchestration
      Models/FoodItem.swift  A saved product + quantity + unit
    Tests/PantryKitTests/  Swift Testing unit tests

  MealKit/                Local Swift package: the meals feature's state
                          and logic, UI-agnostic, depending only on
                          FoodFoundation — zero dependency on PantryKit, by
                          design, so the two stay decoupled peers
    Sources/MealKit/
      MealStore.swift       Template CRUD; entry CRUD/lifecycle (log
                            directly as eaten, plan for later, markEaten,
                            undo); day/range nutrition aggregation with
                            completeness reporting; consumption stats;
                            makeIngredient (pure grams/nutrition math,
                            shared with the composition editor's live
                            amount editing) and recentlyUsedIngredients/
                            lastKnownUnit (the "from history" source);
                            entries(on:)/entriesGroupedBySlot(on:) (the day
                            timeline's queries) and stockShortfalls (the
                            pure "needs more than the pantry holds" check,
                            taking availability as a closure so it stays
                            free of any PantryKit dependency)
      Models/               MealTemplate, MealEntry, TemplateIngredient,
                            LoggedIngredient (+ impliedUnit/
                            impliedNutritionPer100g, for editing a
                            historical ingredient's amount with no network
                            call), MealSlot, MealStatus,
                            NutritionCompleteness/DayNutritionTotal/
                            RangeNutritionSummary/ConsumptionStats
    Tests/MealKitTests/    Swift Testing unit tests

  FoodFoundation/        Local Swift package: shared domain types and product
                          lookup, depended on by PantryKit and MealKit
    Sources/FoodFoundation/
      ProductLookup.swift  Maps OpenFoodFactsKit's DTOs to Product/Nutrition;
                            resolves a barcode (.fetch) or a text query
                            (.search) to Product(s); the only file that
                            imports OpenFoodFactsKit
      Models/              Product/Nutrition, ProductUnit,
                            NutritionVariant, FoodCategory, NumericInput
    Tests/FoodFoundationTests/  Swift Testing unit tests

  OpenFoodFactsKit/       Local Swift package: OpenFoodFactsService
                          (fetchProduct by barcode, searchProducts by text
                          query against search-a-licious), FoodProduct,
                          SearchedProduct, Nutriments, OpenFoodFactsError —
                          a standalone client for Open Food Facts' APIs
```

See [AGENTS.md](AGENTS.md) for conventions and more detail aimed at
AI coding assistants working in this repo.
