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

## Build & test

Full Xcode (not just Command Line Tools) is required. If `xcode-select`
points at the Command Line Tools, don't change it system-wide — override
per-command instead:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'generic/platform=iOS Simulator' build
```

There is no test target yet. Verify changes by building and, where
practical, running the app in the simulator or on a physical device (see
"Deploying to a device" below).

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
needed when adding a new file.

- `Foodpoint/State/` — Global, app-wide state. `AppState` is an
  `@Observable` singleton (`AppState.shared`) accessed via
  `@Environment(AppState.self)`. Holds the flat `items: [FoodItem]` list,
  `unitConfigs` (each barcode's default `ProductUnit`, persisted
  independently of `items` so it survives an item being fully consumed),
  and `unitVariants` (additional named package-size variants per barcode).
  `allVariants(forBarcode:)`, `addUnitVariant(_:forBarcode:)`,
  `updateVariant(_:forBarcode:)`, and `removeVariant(_:forBarcode:)` are the
  CRUD surface for variants — go through these rather than mutating
  `unitConfigs`/`unitVariants` directly, since the default lives in a
  different dictionary than the rest and `removeVariant` guards against
  deleting it.
- `Foodpoint/Models/` — Plain data types: `Product`/`Nutrition` (the app's
  own domain model — see "OpenFoodFacts package" below), `FoodItem` (a
  saved product + quantity + unit), `ProductUnit`/`UnitTrackingMode` (how a
  product's quantity is counted — by discrete count or by weight, with the
  grams-per-unit math used for per-unit nutrition — plus a stable `id` and
  user-facing `name` since a barcode can have several named variants), and
  `FoodCategory` (best-effort category/icon guess from Open Food Facts tags).
- `Foodpoint/Views/` — SwiftUI views. Keep view bodies declarative; push
  non-trivial logic into private methods on the view or into the model
  layer (e.g. `ProductUnit.make`) rather than free functions.
- `Foodpoint/Scanners/` — Barcode scanning. Wraps `AVFoundation`
  (`AVCaptureSession`) directly via `UIViewRepresentable`; not a SwiftUI-
  native camera API, and specifically not VisionKit's
  `DataScannerViewController` (device-only, unsupported in Simulator).
- `Foodpoint/OpenFoodFacts/ProductMapping.swift` — the app's *only* file
  that imports the `OpenFoodFacts` package and touches its
  `FoodProduct`/`Nutriments` DTOs; everything else uses `Product`/`Nutrition`.

## OpenFoodFacts package

`Packages/OpenFoodFacts` is a local Swift package (added as a local package
dependency in `project.pbxproj`, product name `OpenFoodFacts`) holding all
networking and wire-format types for the Open Food Facts v2 API:
`OpenFoodFactsService` (the client), `FoodProduct`/`Nutriments` (Decodable
DTOs matching OFF's JSON), and `OpenFoodFactsError`. These are `public` so
the app can consume them, but treat them as **wire-format only** — never
store a `FoodProduct`/`Nutriments` on a model, pass one into a view, or
match on its fields outside `ProductMapping.swift`. Map to `Product`/
`Nutrition` immediately after fetching (see `ScannerView.fetchFoodData`)
and use the app model everywhere else. This separation exists so OFF's API
shape can change, or a second data source can be added later, without
touching the rest of the app.

The package builds standalone too (`cd Packages/OpenFoodFacts && swift
build`) — keep it free of any dependency on the app target. If you add a
file to the package, it's picked up automatically by both `swift build`
and Xcode (SPM target sources, no manifest edit needed) as long as it's
under `Packages/OpenFoodFacts/Sources/OpenFoodFacts/`.

There is currently no `ViewModels/` folder — views that need local state
just use `@State` directly (see `ScannerView`, `ItemDetailView`). Only
introduce a dedicated `@Observable` view model if a view's logic grows
complex enough to warrant testing or reuse independent of the view.

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
