# Foodpoint

Foodpoint is an iOS pantry inventory tracker. Scan a barcode, and the
product's nutrition and brand info (name, brand, category, Nutri-Score,
calories, macros) is pulled live from
[Open Food Facts](https://world.openfoodfacts.org). Saved products live in
one flat, quantity-tracked list.

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

This is an early solo prototype — expect rough edges and missing features.

## Stack

- SwiftUI, Swift 5
- `@Observable` (Observation framework) for state — no third-party
  dependencies
- AVFoundation for barcode scanning
- Open Food Facts public API for product lookup

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

## Project layout

```
Foodpoint/
  FoodpointApp.swift   App entry point
  ContentView.swift    Root tab bar (Items, Scan)
  ScannerView.swift    Scan tab: barcode -> OFF lookup -> save/discard
  State/               Global app state (AppState, @Observable singleton)
  Models/               FoodItem, ProductUnit, FoodCategory
  Views/                Items list, item detail, package-size management, shared row/card components
  Scanners/             Barcode scanning (AVFoundation-backed UIViewRepresentable)
  OpenFoodFacts/         Networking + models for the Open Food Facts API
```

See [AGENTS.md](AGENTS.md) for conventions and more detail aimed at
AI coding assistants working in this repo.
