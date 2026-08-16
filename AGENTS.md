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
state and CRUD logic on top of it (each with its own unit test suite);
`FoodpointKit` is a thin composition root exposing all of this as a single
`AppState`, the object the app actually injects into its environment. The
`Foodpoint` app target is a thin driver: SwiftUI views, the AVFoundation
camera wrapper, and glue code that reads/writes `appState.pantry.*`.
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
```

(`FoodpointKit` has no test target right now — see its bullet below.)

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
    latter injects `AppState.shared` into the environment. `ScannerView`
    has two acquisition entry points into the same downstream save flow:
    the camera (`FastFoodBarcodeScanner`) and `Views/ProductSearchView.swift`
    (text search); a search result is re-resolved by its barcode via
    `fetchFoodData(for:)` rather than reusing the already-fetched product,
    so there's exactly one code path past that point, not two to maintain.
  - `Views/` — SwiftUI views. Keep bodies declarative; push non-trivial
    logic into `PantryKit` (a new/extended `PantryStore` method, reached
    via `appState.pantry`) or a `FoodFoundation` computed property, rather
    than into the view.
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
  `FoodFoundation` and `PantryKit` (both re-exported — see below):
  - `Sources/FoodpointKit/AppState.swift` — the `@Observable` state
    container the app actually uses, via the `AppState.shared` singleton
    and `@Environment(AppState.self)`; `init()` is public rather than
    private specifically so tests can construct isolated instances instead
    of sharing global state across test cases. Holds no logic of its own —
    just `public let pantry = PantryStore()` (and, once `MealKit` exists,
    `meals: MealStore` alongside it). Deliberately **no forwarding
    properties**: call sites go through `appState.pantry.*`, not
    `appState.*`, since re-declaring `PantryStore`'s whole surface here
    would just be boilerplate duplicating an API one property away (see
    package-architecture.md §3.5). `@_exported import FoodFoundation` and
    `@_exported import PantryKit` at the top mean any file that imports
    `FoodpointKit` (the app included) can use `Product`, `PantryStore`,
    `FoodItem`, etc. directly without importing those packages itself —
    keep those re-exports if you touch this file's imports.
  - **No test target right now.** Composing `pantry: PantryStore` is pure
    wiring with no logic of its own to test; `FoodpointKitTests` returns
    once cross-domain orchestration lands here (e.g. a future meal-logged
    event decrementing pantry stock — see package-architecture.md §3.5,
    §4.2). An empty declared test target makes `swift test` hard-error
    (`swift build` only warns), so the target is removed rather than left
    empty — re-add it in `Package.swift` when there's something to put in it.

- `Packages/PantryKit/` (local package, product `PantryKit`) — the
  pantry's state and CRUD logic, no `import SwiftUI` anywhere in it.
  Depends on `FoodFoundation` only — no dependency on `FoodpointKit`, and
  (once it exists) no dependency on `MealKit` either; the two are meant to
  stay decoupled peers, per package-architecture.md §1:
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
    independent of any package's state (`PantryKit` and, in future,
    `MealKit` each call whichever they need directly, never through one
    another): `ProductLookup.fetch(barcode:)` for a known barcode, and
    `ProductLookup.search(query:)` for free-text search (no barcode
    needed) — see "Product search" below for why the latter maps a
    different DTO, not `FoodProduct` again.
  - `Sources/FoodFoundation/Models/` — Plain data types: `Product`/`Nutrition`
    (the app's own domain model, decoupled from OFF's wire format),
    `ProductUnit`/`UnitTrackingMode` (how a product's quantity is counted —
    by discrete count or by weight, with the grams-per-unit math used for
    per-unit nutrition — plus a stable `id` and user-facing `name` since a
    barcode can have several named variants), `NutritionVariant`/
    `NutritionSource` (a named nutrition data set tagged `.openFoodFacts`
    or `.custom` — mirrors `ProductUnit`'s variant shape), `FoodCategory`
    (best-effort category/icon guess from Open Food Facts tags), and
    `NumericInput` (`String.localizedDouble` — see "Numeric text input"
    below). Note: `ProductUnit`/`NutritionVariant` are the plain *types*
    only — their per-barcode variant CRUD lives in `PantryKit.PantryStore`,
    not here.
    `Nutrition.isEffectivelyEmpty` (all fields nil-or-zero) is the check
    used to treat an Open-Food-Facts entry with no real data as "no data"
    instead of displaying zeroes — some OFF products carry a `nutriments`
    object with every field blank rather than omitting it.
  - `Tests/FoodFoundationTests/` — Swift Testing, same conventions as
    `PantryKitTests`.

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

All four packages build standalone (`cd Packages/<name> && swift build`),
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
