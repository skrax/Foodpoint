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
object the app injects into its environment. The SwiftUI app is a thin
driver on top of all four: views, the camera scanner, and not much else.

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

The Meals tab is a thin placeholder around the meal-composition editor —
the real day timeline/templates screen is still to come, but the editor
itself works: build a meal from ingredient rows, each with an amount and a
"Use from pantry" toggle (on by default), and a running nutrition footer
that flags when data is incomplete rather than silently under-counting.
Ingredients come from four sources — the pantry, previously-logged history
(no network call), scanning, or searching by name (both reusing the same
camera/search flows as the Items tab) — and a barcode `MealKit` has never
used before gets a quick, ingredient-scoped weight/count setup prompt,
independent of the pantry's own configuration for that product even if one
exists. Logging a meal here doesn't yet decrement pantry stock — that
orchestration, and a real day timeline, are still to come.

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
```

(`FoodpointKit` has no test target right now — it's pure composition/wiring
with no logic of its own yet; that returns once it has real orchestration
to test.)

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
    MealsView.swift     Meals tab; today a thin placeholder — a "+" button
                        opens MealCompositionEditorView, and finishing logs
                        the meal directly via appState.meals.logEaten
                        (no pantry orchestration yet)
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
                           `meals: MealStore` as independent peers; no logic
                           of its own beyond composing them (cross-domain
                           orchestration between the two, e.g. logging a
                           meal decrementing pantry stock, is a future
                           addition here, not yet implemented)

  PantryKit/              Local Swift package: pantry state and CRUD, UI-agnostic
    Sources/PantryKit/
      PantryStore.swift    Items, package-size/nutrition variants, and all
                            their CRUD (what used to be on AppState)
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
                            lastKnownUnit (the "from history" source)
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
