# AGENTS.md

Guidance for AI coding assistants working in this repo. See
[README.md](README.md) for a general project overview.

## What this is

Foodpoint is a solo-developer SwiftUI iOS prototype: scan a barcode (or
search by name for something with no barcode — produce, bulk goods), look
up the product on Open Food Facts, and save it into a flat, quantity-
tracked item list. It is early-stage — prefer small, direct changes over
speculative abstractions. (A prior "locations" feature — organizing items
into named places — was built and then deliberately scrapped; the flat
item list is the current, intentional design, not a placeholder.)

All business logic lives in local, UI-agnostic Swift packages (no
`import SwiftUI`, no view code anywhere in them): `FoodFoundation` holds
the shared domain types and product lookup; `PantryKit` holds the pantry's
state and CRUD logic on top of it; `MealKit` holds the meals feature's
state and logic on top of it too — a fully independent peer of `PantryKit`,
sharing nothing with it but `FoodFoundation` (each of the three with its
own unit test suite); `FoodpointKit` is a thin composition root exposing
all of this as a single `AppState`, plus the one place cross-domain
orchestration between `PantryKit` and `MealKit` lives (logging a meal
decrementing pantry stock, and undo restoring it — MK-3; its own,
smaller `FoodpointKitTests`). The `Foodpoint` app target is a thin driver:
SwiftUI views, the AVFoundation camera wrapper, and glue code that
reads/writes `appState.pantry.*`/`appState.meals.*`.
**New logic — state mutation, derived values, parsing, anything that isn't
literally rendering UI — belongs in a package, not in a view.** This split
exists specifically so that logic can be unit tested without a simulator;
don't undermine it by reaching for `@State`/view-local logic where a
testable `PantryStore` method (or a `FoodFoundation` type) would do.

## Build & test

Full Xcode (not just Command Line Tools) is required for the app. If
`xcode-select` points at the Command Line Tools, don't change it
system-wide — override per-command instead:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'generic/platform=iOS Simulator' build
```

Each package's unit tests (Swift Testing) run standalone via SPM, no Xcode
project or simulator needed — this is the fast, primary way to verify
business-logic changes:

```bash
cd Packages/FoodFoundation && swift test
cd Packages/PantryKit && swift test
cd Packages/MealKit && swift test
cd Packages/FoodpointKit && swift test
```

Run the relevant package's tests after any change to it, and add/update
tests for new or changed behavior — see "Testing conventions" below. There
is still no test target for the app/view layer; verify view changes by
building and, where practical, running the app in the simulator or on a
physical device (see "Deploying to a device" below).

## Documentation is mandatory here

Unlike the general default of writing minimal comments, **this repo
requires both of the following on every change that adds, edits, or
removes code:**

1. **Doc comments (`///`)** on new/changed types, properties, and
   non-trivial functions — explain *why*/*what this is for*, not just
   restate the signature. Every existing type in the codebase has one;
   match that standard for anything new.
2. **Update this file and README.md** whenever the change affects project
   structure, conventions, or the feature set they describe. Don't leave
   them describing a previous version of the app.

## Project structure & conventions

The Xcode project uses **file-system synchronized groups**
(`PBXFileSystemSynchronizedRootGroup`), meaning files added under
`Foodpoint/` on disk are picked up automatically — no `.pbxproj` editing
needed when adding a new file to the *app* target. Adding a file to either
*package* also needs no manifest edit (SPM picks up anything under a
target's `Sources`/`Tests` directory) — but adding a whole new package
does require hand-editing `project.pbxproj` (see "Adding a new package
dependency" below).

- `Foodpoint/` (app target) — SwiftUI views and camera glue only, nothing
  else:
  - `ScannerView.swift`, `ContentView.swift`, `FoodpointApp.swift` — the
    latter injects `AppState.shared` into the environment. `ContentView`'s
    root `TabView` has three tabs: Items, Scan, and Meals — the last is
    `Views/MealsView.swift` (MK-2/MK-3), today a thin list-plus-composer
    placeholder (see its own bullet below) that exists purely to make the
    meal composition editor — and now the real logging/undo loop (MK-3) —
    reachable before the real Meals tab (day timeline, templates) lands in
    MK-4/MK-5. `ScannerView` is
    scan-only (UX-2): its single acquisition path is the camera
    (`FastFoodBarcodeScanner`) driving `fetchFoodData(for:)`. It has no
    search UI of its own — `Views/ProductSearchView.swift` (text search)
    is presented directly by `ItemsView`, not by `ScannerView`. Each
    `ProductSearchView` result row also has a separate `info.circle`
    button that pushes `Views/SearchResultDetailView.swift` (a thin wrapper
    around `ProductDetailCard`) to inspect that candidate's nutrition before
    committing — same nested-tappable-controls fix as
    `PackageVariantsView.row(for:)` (plain `HStack` +
    `.contentShape(Rectangle())` + `.onTapGesture` for the row tap, a
    separate `.buttonStyle(.plain)` `Button` for the info icon), and the
    push uses `.navigationDestination(item:)` on the search view's own
    `NavigationStack` rather than a sheet, so popping back doesn't re-run
    the search.
    `ScannerView` is also presentable as a sheet from elsewhere (currently
    `ItemsView`'s "•••" menu) via its `entryPoint: EntryPoint?` parameter
    (`.scan`/`.resolved(barcode:)`/`nil`) — non-`nil` auto-acts on appear
    (skipping the "No Product Scanned" landing screen, since the caller
    already expressed intent by picking a menu item) and shows a Cancel
    button; `nil` is today's Scan-tab-root behavior, unchanged.
    `.resolved(barcode:)` is how a `ProductSearchView` pick — presented and
    resolved to a barcode by `ItemsView` itself, via a second, sequenced
    sheet — still re-enters `ScannerView`'s `fetchFoodData(for:)` rather
    than reusing the already-fetched product, so there's exactly one code
    path past that point, not two to maintain. If you add another entry
    point into this flow, extend `EntryPoint` rather than duplicating `ScannerView`'s
    acquire/confirm/configure/save logic elsewhere — that duplication is
    exactly what this parameter exists to avoid.
  - `Views/` — SwiftUI views. Keep bodies declarative; push non-trivial
    logic into `PantryKit` (a new/extended `PantryStore` method, reached
    via `appState.pantry`) or a `FoodFoundation` computed property, rather
    than into the view. This applies just as much to `MealKit`-backed
    views: push new logic into a `MealStore` method (reached via
    `appState.meals`), not into `@State`/view-local functions.
    - `MealCompositionEditorView.swift` (MK-2) — the meal-composition
      editor: ingredient rows (amount field via `String.localizedDouble`,
      "Use from pantry" toggle defaulting on) plus a running nutrition
      footer with a completeness signal (`MealStore.completeness(for:)`,
      now `public` specifically so this view can call it live, ahead of
      any `MealEntry` existing). Four ingredient sources behind an
      "Add Ingredient" bottom-bar menu, per meals-feature-design.md §6.1:
      **from the pantry** (`MealIngredientPantryPickerView`, reading
      `appState.pantry.items` directly — the one source `MealKit` itself
      can't provide), **from history**
      (`MealIngredientHistoryPickerView`, reading
      `appState.meals.recentlyUsedIngredients()`, no network call),
      **scan** (`FastFoodBarcodeScanner`, reused verbatim from
      `ScannerView`), and **search** (`ProductSearchView`, reused
      verbatim) — both of the latter two funnel into one
      `beginAcquisition(barcode:)` function that calls
      `ProductLookup.fetch(barcode:)` then either appends a row directly
      (this barcode has a `appState.meals.lastKnownUnit(forBarcode:)`
      already) or presents `MealIngredientUnitSetupView`'s minimal
      weight/count + label prompt first (a barcode `MealKit` has never
      used before) — scoped to that one ingredient, never written back to
      `PantryKit` even if the same barcode is already configured there.
      Editing a row's amount recomputes grams/nutrition locally via
      `MealStore.makeIngredient` + `LoggedIngredient.impliedUnit`/
      `.impliedNutritionPer100g` (see the `MealStore.swift` bullet below)
      rather than re-fetching. Deliberately **does not** persist anything
      itself (MK-2's Scope explicitly excludes "actually saving/logging
      the meal") — it hands the composed `[LoggedIngredient]` to an
      `onDone` closure and lets the caller decide; `MealsView` (MK-3) is
      the real caller now, wiring `onDone` into
      `appState.meals.plan`/`appState.markMealEaten(_:)`. Reused as-is for
      template creation (MK-4) and planning (MK-5) is the intent behind
      that closure-based contract.
    - `MealIngredientPantryPickerView.swift`, `MealIngredientHistoryPickerView.swift`,
      `MealIngredientUnitSetupView.swift` (MK-2) — the four sources'
      picker sheets described above.
    - `MealsView.swift` (MK-2/MK-3) — the Meals tab's current placeholder
      body: a "+" button opens `MealCompositionEditorView`; its `onDone`
      plans the composed ingredients (`appState.meals.plan`) then
      immediately calls `appState.markMealEaten(_:)` to transition the
      entry to `.eaten` and apply its pantry orchestration (MK-3,
      package-architecture.md §3.5) — the two-step path because
      `markMealEaten` only operates on a `.planned` entry, matching
      `MealStore.markEaten`'s own contract. If
      `appState.insufficientStockIngredients(for:)` reports any ingredient
      came up short against pantry stock, this shows a non-blocking
      "Insufficient Stock" alert (meals-feature-design.md §4.4's soft
      note) — logging itself already succeeded either way. Each `.eaten`
      row also has a swipe-to-undo action calling
      `appState.undoMealEaten(_:)`, which restores pantry stock exactly
      (see the `FoodpointKit` bullet below) and moves the entry back to
      `.planned`.
  - `Scanners/` — Barcode scanning. Wraps `AVFoundation`
    (`AVCaptureSession`) directly via `UIViewRepresentable`; not a
    SwiftUI-native camera API, and specifically not VisionKit's
    `DataScannerViewController` (device-only, unsupported in Simulator).
  - There is no `ViewModels/` folder — views that need local UI state
    (e.g. a text field's current string) just use `@State` directly. Only
    introduce a dedicated view model if a view's *UI* logic grows complex
    enough to warrant its own tests; state that represents saved/business
    data belongs in `PantryStore` (via `appState.pantry`), not a view model.

- `Packages/FoodpointKit/` (local package, product `FoodpointKit`) — the
  composition root, no `import SwiftUI` anywhere in it. Depends on
  `FoodFoundation`, `PantryKit`, and `MealKit` (all three re-exported —
  see below):
  - `Sources/FoodpointKit/AppState.swift` — the `@Observable` state
    container the app actually uses, via the `AppState.shared` singleton
    and `@Environment(AppState.self)`; `init()` is public rather than
    private specifically so tests can construct isolated instances instead
    of sharing global state across test cases. Holds `public let pantry =
    PantryStore()` and `public let meals = MealStore()` as independent
    peers (neither knows the other exists), plus a private
    `consumedAmounts: [UUID: Double]` (keyed by `LoggedIngredient.id`) used
    only by the orchestration extension below. Deliberately **no
    forwarding properties**: call sites go through
    `appState.pantry.*`/`appState.meals.*`, not `appState.*`, since
    re-declaring `PantryStore`'s/`MealStore`'s whole surface here would
    just be boilerplate duplicating an API one property away (see
    package-architecture.md §3.5). `@_exported import FoodFoundation`,
    `@_exported import PantryKit`, and `@_exported import MealKit` at the
    top mean any file that imports `FoodpointKit` (the app included) can
    use `Product`, `PantryStore`, `FoodItem`, `MealStore`, `MealTemplate`,
    etc. directly without importing those packages itself — keep those
    re-exports if you touch this file's imports.
  - The same file's `extension AppState` (MK-3, package-architecture.md
    §3.5) is this package's whole reason for existing beyond wiring — the
    one place allowed to know both `PantryKit` and `MealKit` exist:
    - `markMealEaten(_ entryID:) -> MealEntry?` — calls `meals.markEaten`,
      then for each ingredient with `usesFromPantry` on, calls
      `pantry.consume(barcode:amount:)`. `consume` clamps to zero rather
      than going negative if stock is short (meals-feature-design.md
      §4.4) instead of blocking; the amount actually taken (which can be
      less than what was logged) is remembered in `consumedAmounts`.
      No-op, including no pantry mutation, if `entryID` isn't currently
      `.planned` — matches `MealStore.markEaten`'s own contract.
    - `undoMealEaten(_ entryID:) -> MealEntry?` — calls `meals.undo`, then
      restores pantry stock for each `usesFromPantry` ingredient by
      exactly the amount recorded in `consumedAmounts` (not naively the
      full logged amount, which would over-restore after a clamp), via
      `pantry.restore(product:unit:amount:)`. `restore` re-creates the
      `FoodItem` if `consume` had fully depleted (and thus deleted) it —
      package-architecture.md §4.3's edge case — using the ingredient's
      own snapshotted `productName`/`productBrand`/`imageURL` plus its
      `impliedUnit`/`impliedNutritionPer100g` to reconstruct a `Product`/
      `ProductUnit`, since `LoggedIngredient` never stores those directly.
    - `insufficientStockIngredients(for entryID:) -> [String]` — a pure
      read of `consumedAmounts`, for the UI to call right after
      `markMealEaten(_:)` and surface meals-feature-design.md §4.4's soft
      inline note without threading `consume`'s return value through the
      call site by hand.
  - `Tests/FoodpointKitTests/MealPantryOrchestrationTests.swift` — Swift
    Testing, covers only this orchestration (package-architecture.md
    §4.2's "much smaller `FoodpointKitTests`"), not `PantryStore`'s/
    `MealStore`'s own logic (that's `PantryKitTests`'/`MealKitTests`' job)
    beyond what's needed to prove the two are wired together correctly —
    the cases from meals-feature-design.md §14's "FoodpointKit
    (orchestration only)" list, plus the insufficient-stock/clamp and
    §4.3 recreate-on-undo cases.

- `Packages/PantryKit/` (local package, product `PantryKit`) — the
  pantry's state and CRUD logic, no `import SwiftUI` anywhere in it.
  Depends on `FoodFoundation` only — no dependency on `FoodpointKit`, and
  no dependency on `MealKit` either; the two are meant to stay decoupled
  peers, per package-architecture.md §1:
  - `Sources/PantryKit/PantryStore.swift` — the `@Observable` store.
    Construct a fresh `PantryStore()` in tests, never a shared singleton —
    it's a single mutable instance and tests may run in any order. Holds
    the flat `items: [FoodItem]` list, plus two parallel variant systems
    keyed by barcode, each with a default (`unitConfigs`/`nutritionConfigs`,
    persisted independently of `items` so they survive an item being fully
    consumed) and alternates (`unitVariants`/`nutritionVariants`). Go
    through the CRUD methods rather than mutating the dictionaries
    directly:
    - Package sizes: `allVariants(forBarcode:)`, `addUnitVariant(_:forBarcode:)`,
      `updateVariant(_:forBarcode:)`, `removeVariant(_:forBarcode:)` (guards
      against deleting the default), `makeDefault(_:forBarcode:)`, and
      `renameUnitLabel(_:forBarcode:)` (the count label — e.g. "slices",
      "bars" — is a barcode-wide property shared by every variant, so this
      renames it everywhere at once rather than letting one variant's label
      drift out of sync with its siblings; a no-op for weight-tracked units,
      whose label is always "g").
    - Nutrition: the same five methods with a `Nutrition`-suffixed/-infixed
      name (`allNutritionVariants`, `addNutritionVariant`,
      `updateNutritionVariant`, `removeNutritionVariant`,
      `makeNutritionDefault`), plus two specific to reconciling with Open
      Food Facts on re-scan: `pendingNutritionUpdate(from:forBarcode:)`
      (decides whether OFF's freshly-fetched data is new/changed enough to
      ask about — `nil` if it's missing, all-zero, or unchanged from
      what's remembered) and `setDefaultNutritionVariant`/
      `refreshNutritionVariant` (apply the user's choice from that
      prompt). See `ScannerView`'s `knownProductNutritionStatus` and
      `NutritionUpdateView` for how the app drives these.
    - Meal-driven consumption (MK-3, called only from `FoodpointKit`'s
      orchestration extension — see its bullet above — never from
      `MealKit`, which has no dependency on this package):
      `consume(barcode:amount:) -> Double` decrements an item, clamping to
      zero via the existing `setQuantity` zero-deletes behavior rather
      than duplicating it, and returns the amount actually taken (less
      than requested if stock was short, letting the caller detect and
      surface that); `restore(product:unit:amount:)` adds back to an
      existing item or fully re-creates one that was deleted at zero
      (package-architecture.md §4.3's undo edge case), preferring the
      barcode's own remembered `unitConfigs`/`nutritionConfigs` entries
      over whatever the caller passed, the same way `addProduct` treats
      its own first-save-wins defaults.
  - `Sources/PantryKit/Models/FoodItem.swift` — a saved product + quantity
    + unit. The one model type that lives here rather than in
    `FoodFoundation`, since it's pantry-state shaped (references a live
    `Product`), not a shared domain vocabulary type — `MealKit` will never
    have a `FoodItem` of its own.
  - `Tests/PantryKitTests/` — Swift Testing (`import Testing`, `@Test`,
    `#expect`), not XCTest. See "Testing conventions" below.

- `Packages/FoodFoundation/` (local package, product `FoodFoundation`) —
  shared domain types and product lookup, no dependency on `FoodpointKit`
  or the app. Depends on `OpenFoodFactsKit`:
  - `Sources/FoodFoundation/ProductLookup.swift` — the *only* file, in the
    whole dependency graph, that imports `OpenFoodFactsKit` and touches its
    `FoodProduct`/`SearchedProduct`/`Nutriments` DTOs directly; everywhere
    else works with `Product`/`Nutrition`. Two stateless entry points, both
    independent of any package's state (`PantryKit` and `MealKit` each call
    whichever they need directly, never through one another):
    `ProductLookup.fetch(barcode:)` for a known barcode, and
    `ProductLookup.search(query:)` for free-text search (no barcode
    needed) — see "Product search" below for why the latter maps a
    different DTO, not `FoodProduct` again.
  - `Sources/FoodFoundation/Models/` — Plain data types: `Product`/`Nutrition`
    (the app's own domain model, decoupled from OFF's wire format;
    `Nutrition` is `Codable`/`Equatable` so `MealKit`'s
    `LoggedIngredient.nutritionSnapshot` can embed and eventually persist
    it directly),
    `ProductUnit`/`UnitTrackingMode` (how a product's quantity is counted —
    by discrete count or by weight, with the grams-per-unit math used for
    per-unit nutrition — plus a stable `id` and user-facing `name` since a
    barcode can have several named variants; `ProductUnit` is also
    `Codable`/`Equatable` for the same reason, since `MealKit`'s
    `TemplateIngredient.unit` embeds it), `NutritionVariant`/
    `NutritionSource` (a named nutrition data set tagged `.openFoodFacts`
    or `.custom` — mirrors `ProductUnit`'s variant shape), `FoodCategory`
    (best-effort category/icon guess from Open Food Facts tags), and
    `NumericInput` (`String.localizedDouble` — see "Numeric text input"
    below). Note: `ProductUnit`/`NutritionVariant` are the plain *types*
    only — their per-barcode variant CRUD lives in `PantryKit.PantryStore`,
    not here (and `MealKit` has no equivalent per-barcode CRUD at all —
    see its bullet below).
    `Nutrition.isEffectivelyEmpty` (all fields nil-or-zero) is the check
    used to treat an Open-Food-Facts entry with no real data as "no data"
    instead of displaying zeroes — some OFF products carry a `nutriments`
    object with every field blank rather than omitting it.
  - `Tests/FoodFoundationTests/` — Swift Testing, same conventions as
    `PantryKitTests`.

- `Packages/MealKit/` (local package, product `MealKit`) — the meals
  feature's state and logic, no `import SwiftUI` anywhere in it — now
  UI-visible via the app's Meals tab (MK-2's composition editor, wired to a
  real "Save"/logging action plus pantry orchestration by MK-3, in
  `FoodpointKit`). Depends on `FoodFoundation` **only** — no dependency on
  `PantryKit`, checked by grep in this package's own acceptance criteria
  (MK-1); see package-architecture.md §1/§3.4 for the "treat `PantryKit`
  and `MealKit` like separate applications" rule this exists to enforce:
  - `Sources/MealKit/MealStore.swift` — the `@Observable` store. Construct
    a fresh `MealStore()` in tests, same rule as `PantryStore`. Holds
    `templates: [MealTemplate]` and `entries: [MealEntry]`, plus template
    CRUD (`addTemplate`/`updateTemplate`/`removeTemplate`) and entry
    CRUD/lifecycle:
    - `makeIngredient(barcode:productName:productBrand:imageURL:nutritionPer100g:amount:unit:usesFromPantry:)` —
      `public static`, pure, and network-free: the actual
      `grams = amount × unit.gramsPerUnit` + nutrition-scaling arithmetic
      shared by `resolveIngredient` and `instantiate` below. Extracted
      specifically so `Foodpoint/Views/MealCompositionEditorView.swift`
      (MK-2) can rebuild a `LoggedIngredient` for a locally-edited amount
      without re-fetching — pair with `LoggedIngredient.impliedUnit`/
      `.impliedNutritionPer100g` (see the Models bullet below) to
      round-trip an already-resolved ingredient through this function
      again for a new amount.
    - `resolveIngredient`/`resolveTemplateIngredient` — resolve a barcode
      and snapshot everything a `LoggedIngredient`/`TemplateIngredient`
      needs (name, brand, image, and, for the logged variant, nutrition
      via `makeIngredient`) immediately, one network call, right now —
      never deferred, so browsing an already-added ingredient later needs
      no further call.
    - `instantiate(_:)` — turns a `MealTemplate`'s ingredients into
      `LoggedIngredient`s by **re-resolving nutrition fresh** via
      `ProductLookup.fetch` every single time, never reusing a previous
      instantiation's cached value (meals-feature-design.md §4.1) — the
      network cost is accepted, same tradeoff re-scanning a barcode
      already has elsewhere in this app. `logTemplate`/`planTemplate` wrap
      this plus `logEaten`/`plan` for one-tap logging.
    - `recentlyUsedIngredients()` — every distinct barcode this store has
      ever logged, one `LoggedIngredient` each, most-recently-used entry
      first; reads straight off already-snapshotted fields, so — unlike
      scan/search — it's the "from history" ingredient source (§6.1 #2)
      and never makes a network call. `lastKnownUnit(forBarcode:)` is the
      companion lookup for the *unit*, checked by the composition editor
      before prompting its first-time unit setup — `nil` means this
      barcode has never been used as a `MealKit` ingredient before,
      deliberately never falling back to `PantryKit`'s own unit config for
      the same barcode even if one exists.
    - `logEaten`/`plan` — create an entry as `.eaten` or `.planned`
      directly from already-resolved ingredients.
    - `markEaten(_:)`/`undo(_:)` — transition `.planned` <-> `.eaten` and
      return the finalized/reverted `MealEntry`, **never touching
      inventory themselves**. The caller (`FoodpointKit.AppState.markMealEaten`/
      `.undoMealEaten`, MK-3) iterates `entry.ingredients` where
      `usesFromPantry` is `true` to decrement/restore the right pantry
      items — see package-architecture.md §3.5's example and the
      `FoodpointKit` bullet above. `removeEntry` follows the same "hand
      back what changed" contract, returning the deleted entry, but has no
      `FoodpointKit`-level caller yet (still MK-4/MK-5 territory).
    - `dayTotal(for:)`/`rangeSummary(from:to:)` — nutrition aggregation.
      `.eaten` and `.planned` totals are always kept separate, never
      summed (meals-feature-design.md §8.1), and every total is a
      `NutritionCompleteness` carrying `missingCount` alongside the sum —
      never trust/display a total without checking `isComplete` first
      (§8.2, mirrors `Nutrition.isEffectivelyEmpty`'s honesty principle).
      `rangeSummary` includes every calendar day in the range, even ones
      with zero entries, so `averageEatenPerDay` is a true per-day average.
      Both build on `completeness(for:)`, `public static` (not just
      `private`) specifically so the composition editor's live running
      footer (MK-2) can compute the same signal over whatever's currently
      in the editor, ahead of any `MealEntry` existing.
    - `consumptionStats(barcode:from:to:)`/`mostConsumed(from:to:)` — how
      often/how much a product was eaten; counts every `.eaten` ingredient
      row regardless of `usesFromPantry` ("did I eat this" != "did it come
      from my shelf" — meals-feature-design.md §9).
    - `MealStore.init(productResolver:)` takes a `ProductResolver =
      @Sendable (String) async throws -> Product` closure, defaulting to
      `FoodFoundation.ProductLookup.fetch`. This is a testability seam
      only — production code never overrides it — since
      `OpenFoodFactsService` has no protocol/DI seam of its own to stub in
      tests; `MealKitTests`' `StubProductResolver` (an `actor`, for
      thread-safe call counting) is injected here instead of making live
      network calls, the same no-live-network rule
      `FoodFoundationTests`/`PantryKitTests` already follow.
  - `Sources/MealKit/Models/` — `MealTemplate` (name + default slot +
    `[TemplateIngredient]`, no nutrition, no date/history — a live recipe,
    re-resolved on each use), `MealEntry` (date + slot + status + name +
    optional `templateID` + `[LoggedIngredient]` — one row on the
    timeline), `TemplateIngredient` (barcode/productName/productBrand/
    imageURL/amount/`unit: ProductUnit`/usesFromPantry — `unit` isn't
    broken out in the design doc's summary ER diagram but is required to
    make `amount` meaningful and to support genuine one-tap logging
    without re-asking "weight or count?" every time; scoped to this
    ingredient alone, never shared with `PantryKit`'s per-barcode
    configuration even for the same barcode), `LoggedIngredient` (same
    identity fields as `TemplateIngredient` plus `unitLabel`,
    `gramsResolved`, and `nutritionSnapshot: Nutrition?` — all frozen at
    logging time, never re-touched afterward: **pantry state is live, meal
    history is frozen**, meals-feature-design.md §4.3). `LoggedIngredient`
    also has two computed properties, `impliedUnit`/
    `impliedNutritionPer100g`, that reconstruct (respectively) the
    `ProductUnit` and per-100g `Nutrition` this ingredient was logged
    with, by inverting the `gramsResolved`/`amount` ratio and the
    `scaled(by:)` call `makeIngredient` applied — what lets the "from
    history" ingredient source (§6.1 #2, MK-2) let the amount be edited
    without a network call, since `LoggedIngredient` itself doesn't store
    a full `ProductUnit`/raw per-100g `Nutrition`, only the frozen,
    already-scaled results. `MealSlot`
    (`.breakfast`/`.lunch`/`.dinner`/`.snack`, fixed — not user-configurable
    — with a `current(at:calendar:)` time-of-day default), `MealStatus`
    (`.planned`/`.eaten`), and `NutritionCompleteness`/`DayNutritionTotal`/
    `RangeNutritionSummary`/`ConsumptionStats` (the aggregation/stats
    result types `MealStore` returns).
  - `Sources/MealKit/NutritionMath.swift` — `internal` `+`/`/` operators on
    `FoodFoundation.Nutrition`, used only by this package's aggregation.
    Kept local to `MealKit` rather than added to `FoodFoundation`, since
    summing nutrition is a meals-specific concern nothing in `PantryKit`
    needs.
  - `Tests/MealKitTests/` — Swift Testing, same conventions as
    `PantryKitTests`/`FoodFoundationTests`; see `TestSupport.swift`'s
    `StubProductResolver`/`Fixture` for this package's fixture pattern.
    `IngredientCompositionTests.swift` (MK-2) covers the pure,
    network-free logic added for the composition editor —
    `makeIngredient`, the public `completeness(for:)`,
    `recentlyUsedIngredients()`, `lastKnownUnit(forBarcode:)`, and
    `LoggedIngredient.impliedUnit`/`.impliedNutritionPer100g` — all
    without a `StubProductResolver`, since none of it makes a resolver
    call.

- `Packages/OpenFoodFactsKit/` (local package, product `OpenFoodFactsKit`) —
  all networking and wire-format types for Open Food Facts' APIs:
  `OpenFoodFactsService` (the client) with two methods hitting two
  different services — `fetchProduct(barcode:)` (the v2 product API,
  `world.openfoodfacts.org`) and `searchProducts(query:)` (search-a-licious,
  `search.openfoodfacts.org` — see "Product search" below for why it's a
  separate service, not a parameter on the v2 API) — plus `FoodProduct`/
  `SearchedProduct`/`Nutriments` (Decodable DTOs) and `OpenFoodFactsError`.
  Public so `FoodFoundation` can consume them, but treat them as
  **wire-format only** — never store one on a model or pass one outside
  `ProductLookup.swift`. Has no dependency on any other package
  (dependency direction is one-way: `Foodpoint` app -> `FoodpointKit` ->
  `PantryKit` -> `FoodFoundation` -> `OpenFoodFactsKit`).

All five packages build standalone (`cd Packages/<name> && swift build`),
and are kept free of any dependency on the app target — that's what makes
them unit-testable without a simulator.

## Numeric text input

Never parse a user-typed number with plain `Double(someText)`. A
`.decimalPad` keyboard shows "," as the decimal separator key in many
locales (e.g. German) — `Double.init?(String)` only ever accepts "." and
silently returns `nil` for "5,2", dropping the value as if never entered.
This was a real, previously-shipped bug. Always use
`someText.localizedDouble` (`FoodFoundation`'s `String` extension) instead,
in both the app and any new package code.

## Product search

Open Food Facts' v2/v3 product API does **not** support free-text search —
confirmed against the live API and current docs while building this, not
assumed. Text search goes through a genuinely different service,
search-a-licious (`search.openfoodfacts.org`), with its own response
shape. The one field that actually differs from `FoodProduct` (confirmed
by comparing real responses from both endpoints): **`brands` is an array**
on search results (`["Fresh Banana"]`) where the by-barcode endpoint
returns a single comma-separated string (`"Nutella, Ferrero"`). That's why
`SearchedProduct` is its own type rather than reusing `FoodProduct` — decode
one endpoint's JSON as the other's DTO and it silently fails or crashes.
`Product(searchedProduct:)` joins the array with `", "` so the rest of the
app never has to know which acquisition path a `Product` came from. The
nested `nutriments` object uses identical field names on both endpoints,
so `Nutriments`/`Nutrition.init(offNutriments:)` are reused unchanged.

If Open Food Facts' search API changes again, re-verify against the live
endpoint (`curl` it) rather than assuming the response shape — that's what
caught this the first time.

## Testing conventions

Every package's test target uses **Swift Testing**, not XCTest —
`import Testing`, `@Suite`/`@Test`, `#expect(...)`/`#require(...)`, `throws`
for tests that need to fail loudly on setup errors. Match this style for
new tests rather than introducing XCTest.

- Construct a fresh `PantryStore()` per test — never share a global
  singleton across tests, since it's a single mutable instance and tests
  may run in any order.
- Test business logic (`PantryStore`'s CRUD in `PantryKitTests`; model
  computed properties/static factories like `ProductUnit.make` in
  `FoodFoundationTests`) thoroughly; there is no view-layer test target,
  so don't try to test SwiftUI views here.
- `FoodFoundationTests/ProductMappingTests.swift` builds
  `OpenFoodFactsKit.FoodProduct` fixtures by decoding realistic JSON
  strings (`JSONDecoder().decode(FoodProduct.self, from:)`) rather than a
  memberwise initializer — the OFF package intentionally has no public
  memberwise init for its DTOs (only the synthesized `Decodable.init(from:)`),
  so this is also the only test approach that would actually notice a
  `CodingKeys` mistake.
- When you fix a bug, add a regression test for it in the same commit, in
  whichever package's test target actually owns the affected code — see
  `FoodFoundationTests/NumericInputTests.swift`'s comma-decimal test for
  the pattern (name the test after the bug, not just the feature).
- `MealKitTests` never makes a live network call: `MealStore` takes a
  `productResolver` closure (defaulting to `FoodFoundation.ProductLookup.fetch`
  in production), and tests inject `TestSupport.swift`'s
  `StubProductResolver` instead — an `actor` so its call count can be read
  safely from `async` test bodies. Use this same seam rather than adding a
  new one if `MealStore` grows another network-calling method.

## Adding a new package dependency

Adding a local Swift package to the Xcode project (a new package, not a
new file in an existing one) requires hand-editing `project.pbxproj` — this
project has no packages added via Xcode's GUI to copy prior art from; the
existing `OpenFoodFactsKit`/`FoodpointKit`/`FoodFoundation`/`PantryKit`
entries (all hand-added the same way) are the template. The shape needed
(see the existing `F00DFACE...` entries as a template):
1. A `PBXBuildFile` wrapping a `productRef` (in the app target's
   `Frameworks` build phase's `files`).
2. An `XCLocalSwiftPackageReference` (`relativePath` to the package
   directory) added to the project's `packageReferences`.
3. An `XCSwiftPackageProductDependency` referencing that package reference,
   added to the target's `packageProductDependencies`.
Generate fresh, non-colliding 24-hex-character object IDs for each (the
existing entries use an `F00DFACE...` prefix purely as a readable marker,
not a requirement) — then build immediately to confirm the graph resolves
before making further changes.

## Deploying to a device

If the user has granted standing permission to deploy to a connected
physical iPhone for the session, after building for the simulator also
build/install/launch on the device:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'id=<device-udid>' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device install app --device <device-udid> \
  <path-to>/Foodpoint.app

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device process launch --device <device-udid> fseidl.Foodpoint
```

Find the device UDID with `xcrun xctrace list devices`. If launch fails
with a "device not unlocked" error, the build/install still succeeded —
just ask the user to unlock and open the app themselves.

## Style notes

- Prefer editing/extending existing files over introducing new
  abstractions or dependencies. This is a small prototype; don't add
  frameworks, DI containers, or layers it doesn't need yet.
- See "Documentation is mandatory here" above — this repo's comment
  policy is an explicit exception to the general minimal-comments default.
