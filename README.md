# Foodpoint

Foodpoint is an iOS pantry inventory tracker. Scan a barcode, and the
product's nutrition and brand info (name, brand, category, Nutri-Score,
calories, macros) is pulled live from
[Open Food Facts](https://world.openfoodfacts.org). Saved products live in
one flat, quantity-tracked list.

All of the app's business logic — state, models, and the Open Food Facts
integration — lives in a local, UI-agnostic Swift package
(`Packages/FoodpointKit`) with its own unit test suite. The SwiftUI app is
a thin driver on top of it: views, the camera scanner, and not much else.

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
scanner and an item's detail view.

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

This is an early solo prototype — expect rough edges and missing features.

## Stack

- SwiftUI, Swift 5
- `@Observable` (Observation framework) for state — no third-party
  dependencies
- AVFoundation for barcode scanning
- Open Food Facts public API for product lookup
- Swift Testing for `FoodpointKit`'s unit tests

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

Run `FoodpointKit`'s unit tests directly with Swift Package Manager,
without touching Xcode or a simulator:

```bash
cd Packages/FoodpointKit && swift test
```

## Project layout

```
Foodpoint/
  FoodpointApp.swift   App entry point
  ContentView.swift    Root tab bar (Items, Scan)
  ScannerView.swift    Scan tab: barcode -> AppState.lookupProduct -> save/discard
  Views/               SwiftUI views only — no business logic
  Scanners/             Barcode scanning (AVFoundation-backed UIViewRepresentable)

Packages/
  FoodpointKit/          Local Swift package: all business logic, UI-agnostic
    Sources/FoodpointKit/
      AppState.swift      App state + all CRUD logic (items, units, nutrition)
      ProductMapping.swift  Maps OpenFoodFacts' DTOs to Product/Nutrition;
                             the only file that imports OpenFoodFacts
      Models/              Product/Nutrition, FoodItem, ProductUnit,
                            NutritionVariant, FoodCategory, NumericInput
    Tests/FoodpointKitTests/  Swift Testing unit tests

  OpenFoodFacts/          Local Swift package: OpenFoodFactsService,
                          FoodProduct, Nutriments, OpenFoodFactsError —
                          a standalone client for the OFF v2 API
```

See [AGENTS.md](AGENTS.md) for conventions and more detail aimed at
AI coding assistants working in this repo.
