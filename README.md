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

The Meals tab is a thin placeholder around the meal-composition editor —
the real day timeline screen is still to come, but the core logging loop
works end to end: build a meal from ingredient rows, each with an amount
and a "Use from pantry" toggle (on by default), and a running nutrition
footer that flags when data is incomplete rather than silently
under-counting. Ingredients come from four sources — the pantry,
previously-logged history (no network call), scanning, or searching by
name (both reusing the same camera/search flows as the Items tab) — and a
barcode `MealKit` has never used before gets a quick, ingredient-scoped
weight/count setup prompt, independent of the pantry's own configuration
for that product even if one exists.

Tapping "Done" logs the meal and decrements pantry stock for every
ingredient with "Use from pantry" on — ingredients with the toggle off
(take-out, a friend's leftovers) are logged for nutrition/history without
touching inventory at all. If the pantry doesn't have enough of something,
the decrement clamps to zero instead of going negative or blocking the
log, with a soft "Insufficient Stock" note naming what came up short.
Swiping an eaten meal offers "Undo," which restores pantry stock by
exactly what was actually taken (not naively the full logged amount, if a
clamp happened) — including re-creating a pantry item that eating the last
of it had fully removed. Editing a product's nutrition later never rewrites
an already-eaten meal's numbers: pantry state is live, meal history is a
frozen snapshot.

A meal you log often can be saved as a **template** and logged again with
one tap — the fast path templates exist for: tap a memorized meal in the
"Templates" list and it's logged to today at the current slot, pantry
decremented, with nutrition re-resolved fresh (never a stale cached
value) so a later correction to a product's data is reflected. Templates
get created two ways: explicitly, from a "New Meal" editor that reuses
the same ingredient-composition UI (also used to "Edit" a template's
ingredients later); or promoted from something already logged — after an
ad-hoc log, a "Remember this meal?" prompt offers to save it, reusing the
scanner's own package-size-naming prompt verbatim (a name field, "Save
Variant"/"Just This Once"/"Cancel"). Templates can be renamed, edited
(name, default slot, and ingredients), and deleted from the Templates
list, all without affecting meals already logged from them.

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
    MealsView.swift     Meals tab; a "Templates" row links to
                        TemplatesListView, then a "+" button opens
                        MealCompositionEditorView for an ad-hoc meal —
                        "Done" plans it then immediately marks it eaten
                        (appState.markMealEaten), decrementing pantry
                        stock for "Use from pantry" ingredients, surfacing
                        a soft note if stock ran short, then offering
                        "Remember this meal?" to save it as a template.
                        Each eaten row has a swipe-to-undo action
                        (appState.undoMealEaten) that restores pantry
                        stock exactly
    MealCompositionEditorView.swift  Ingredient rows + running nutrition
                        footer with a completeness signal; four ingredient
                        sources (pantry/history/scan/search) behind an
                        "Add Ingredient" menu; reused by TemplateEditorView
                        for template creation/editing too
    MealIngredientPantryPickerView.swift, MealIngredientHistoryPickerView.swift,
    MealIngredientUnitSetupView.swift  The four sources' picker sheets used
                        by the composition editor
    TemplatesListView.swift  Templates list: tap a row to log it in one
                        tap (TemplateLogButton), "+" to create one, swipe/
                        context menu to rename, edit, or delete
    TemplateEditorView.swift  "New Meal"/"Edit" template form (name,
                        default slot, ingredients via
                        MealCompositionEditorView)
    TemplateLogButton.swift  Reusable one-tap-log control with its own
                        loading/error state
    RememberMealPrompt.swift  The "Remember this meal?" prompt (reuses
                        ScannerView's package-size-naming alert verbatim)
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
                           UI), and logTemplateAndMarkEaten (one-tap
                           template logging: instantiate, plan, then
                           markMealEaten, so it decrements pantry
                           identically to a manual log)
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
                            undo); logTemplate/planTemplate (instantiate a
                            template fresh, then log/plan it); day/range
                            nutrition aggregation with completeness
                            reporting; consumption stats; makeIngredient
                            (pure grams/nutrition math, shared with the
                            composition editor's live amount editing) and
                            recentlyUsedIngredients/lastKnownUnit (the
                            "from history" source)
      Models/               MealTemplate, MealEntry, TemplateIngredient
                            (+ init(logged:), demoting a LoggedIngredient
                            back into a template row for "Remember this
                            meal?"/template editing), LoggedIngredient
                            (+ impliedUnit/impliedNutritionPer100g, for
                            editing a historical ingredient's amount with
                            no network call), MealSlot, MealStatus,
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
