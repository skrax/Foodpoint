# AGENTS.md

Guidance for AI coding assistants working in this repo. See
[README.md](README.md) for a general project overview.

## What this is

Foodpoint is a solo-developer SwiftUI iOS prototype: scan a barcode, look
up the product on Open Food Facts, and save it into a flat, quantity-
tracked item list. It is early-stage — prefer small, direct changes over
speculative abstractions. (A prior "locations" feature — organizing items
into named places — was built and then deliberately scrapped; the flat
item list is the current, intentional design, not a placeholder.)

All business logic lives in the local `FoodpointKit` package, which is
UI-agnostic (no `import SwiftUI`, no view code) and has its own unit test
suite. The `Foodpoint` app target is a thin driver: SwiftUI views, the
AVFoundation camera wrapper, and glue code that calls into `FoodpointKit`.
**New logic — state mutation, derived values, parsing, anything that isn't
literally rendering UI — belongs in `FoodpointKit`, not in a view.** This
split exists specifically so that logic can be unit tested without a
simulator; don't undermine it by reaching for `@State`/view-local logic
where a testable `AppState` method would do.

## Build & test

Full Xcode (not just Command Line Tools) is required for the app. If
`xcode-select` points at the Command Line Tools, don't change it
system-wide — override per-command instead:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'generic/platform=iOS Simulator' build
```

`FoodpointKit`'s unit tests (Swift Testing) run standalone via SPM, no
Xcode project or simulator needed — this is the fast, primary way to
verify business-logic changes:

```bash
cd Packages/FoodpointKit && swift test
```

Run this after any change to `FoodpointKit`, and add/update tests for new
or changed behavior — see "Testing conventions" below. There is still no
test target for the app/view layer; verify view changes by building and,
where practical, running the app in the simulator or on a physical device
(see "Deploying to a device" below).

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
    latter injects `AppState.shared` into the environment.
  - `Views/` — SwiftUI views. Keep bodies declarative; push non-trivial
    logic into `FoodpointKit` (a new/extended `AppState` method, or a
    computed property on a model type) rather than into the view.
  - `Scanners/` — Barcode scanning. Wraps `AVFoundation`
    (`AVCaptureSession`) directly via `UIViewRepresentable`; not a
    SwiftUI-native camera API, and specifically not VisionKit's
    `DataScannerViewController` (device-only, unsupported in Simulator).
  - There is no `ViewModels/` folder — views that need local UI state
    (e.g. a text field's current string) just use `@State` directly. Only
    introduce a dedicated view model if a view's *UI* logic grows complex
    enough to warrant its own tests; state that represents saved/business
    data belongs in `AppState`, not a view model.

- `Packages/FoodpointKit/` (local package, product `FoodpointKit`) — all
  business logic, no `import SwiftUI` anywhere in it:
  - `Sources/FoodpointKit/AppState.swift` — the `@Observable` state
    container. The app uses the `AppState.shared` singleton via
    `@Environment(AppState.self)`; `init()` is public rather than private
    specifically so tests can construct isolated instances instead of
    sharing global state across test cases — always construct a fresh
    `AppState()` in a test, never touch `.shared`. Holds the flat
    `items: [FoodItem]` list, plus two parallel variant systems keyed by
    barcode, each with a default (`unitConfigs`/`nutritionConfigs`,
    persisted independently of `items` so they survive an item being fully
    consumed) and alternates (`unitVariants`/`nutritionVariants`). Go
    through the CRUD methods rather than mutating the dictionaries
    directly:
    - Package sizes: `allVariants(forBarcode:)`, `addUnitVariant(_:forBarcode:)`,
      `updateVariant(_:forBarcode:)`, `removeVariant(_:forBarcode:)` (guards
      against deleting the default), `makeDefault(_:forBarcode:)`.
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
  - `Sources/FoodpointKit/ProductMapping.swift` — the *only* file, in the
    app or either package, that imports `OpenFoodFacts` and touches its
    `FoodProduct`/`Nutriments` DTOs directly; everywhere else works with
    `Product`/`Nutrition`. Also defines `AppState.lookupProduct(barcode:)`,
    the single call `ScannerView` makes to fetch-and-map — the app itself
    never imports `OpenFoodFacts`.
  - `Sources/FoodpointKit/Models/` — Plain data types: `Product`/`Nutrition`
    (the app's own domain model, decoupled from OFF's wire format),
    `FoodItem` (a saved product + quantity + unit), `ProductUnit`/
    `UnitTrackingMode` (how a product's quantity is counted — by discrete
    count or by weight, with the grams-per-unit math used for per-unit
    nutrition — plus a stable `id` and user-facing `name` since a barcode
    can have several named variants), `NutritionVariant`/`NutritionSource`
    (a named nutrition data set tagged `.openFoodFacts` or `.custom` —
    mirrors `ProductUnit`'s variant shape), `FoodCategory` (best-effort
    category/icon guess from Open Food Facts tags), and `NumericInput`
    (`String.localizedDouble` — see "Numeric text input" below).
    `Nutrition.isEffectivelyEmpty` (all fields nil-or-zero) is the check
    used to treat an Open-Food-Facts entry with no real data as "no data"
    instead of displaying zeroes — some OFF products carry a `nutriments`
    object with every field blank rather than omitting it.
  - `Tests/FoodpointKitTests/` — Swift Testing (`import Testing`, `@Test`,
    `#expect`), not XCTest. See "Testing conventions" below.

- `Packages/OpenFoodFacts/` (local package, product `OpenFoodFacts`) — all
  networking and wire-format types for the Open Food Facts v2 API:
  `OpenFoodFactsService` (the client), `FoodProduct`/`Nutriments`
  (Decodable DTOs matching OFF's JSON), and `OpenFoodFactsError`. Public so
  `FoodpointKit` can consume them, but treat them as **wire-format only** —
  never store one on a model or pass one outside `ProductMapping.swift`.
  Has no dependency on `FoodpointKit` (dependency direction is one-way:
  `Foodpoint` app -> `FoodpointKit` -> `OpenFoodFacts`).

Both packages build standalone (`cd Packages/<name> && swift build`), and
are kept free of any dependency on the app target — that's what makes
`FoodpointKit` unit-testable without a simulator.

## Numeric text input

Never parse a user-typed number with plain `Double(someText)`. A
`.decimalPad` keyboard shows "," as the decimal separator key in many
locales (e.g. German) — `Double.init?(String)` only ever accepts "." and
silently returns `nil` for "5,2", dropping the value as if never entered.
This was a real, previously-shipped bug. Always use
`someText.localizedDouble` (`FoodpointKit`'s `String` extension) instead,
in both the app and any new package code.

## Testing conventions

`FoodpointKit`'s test target uses **Swift Testing**, not XCTest —
`import Testing`, `@Suite`/`@Test`, `#expect(...)`/`#require(...)`, `throws`
for tests that need to fail loudly on setup errors. Match this style for
new tests rather than introducing XCTest.

- Construct a fresh `AppState()` per test — never share `AppState.shared`
  across tests, since it's a single mutable instance and tests may run in
  any order.
- Test business logic (`AppState`, model computed properties/static
  factories like `ProductUnit.make`) thoroughly; there is no view-layer
  test target, so don't try to test SwiftUI views here.
- `ProductMappingTests` builds `OpenFoodFacts.FoodProduct` fixtures by
  decoding realistic JSON strings (`JSONDecoder().decode(FoodProduct.self,
  from:)`) rather than a memberwise initializer — the OFF package
  intentionally has no public memberwise init for its DTOs (only the
  synthesized `Decodable.init(from:)`), so this is also the only test
  approach that would actually notice a `CodingKeys` mistake.
- When you fix a bug in `FoodpointKit`, add a regression test for it in
  the same commit — see `NumericInputTests`'s comma-decimal test for the
  pattern (name the test after the bug, not just the feature).

## Adding a new package dependency

Adding a local Swift package to the Xcode project (a new package, not a
new file in an existing one) requires hand-editing `project.pbxproj` —
this project has no other packages' worth of prior art beyond
`OpenFoodFacts`/`FoodpointKit` to copy from via Xcode's GUI history. The
shape needed (see the existing `F00DFACE...` entries as a template):
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
