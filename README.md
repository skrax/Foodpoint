# Foodpoint

Foodpoint is an iOS pantry inventory tracker. You organize food into
locations (fridge, pantry, freezer, ...) and add items by scanning their
barcode — nutrition and product data (name, brand, Nutri-Score, calories,
macros) is pulled live from [Open Food Facts](https://world.openfoodfacts.org).

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
  State/          Global app state (AppState, @Observable singleton)
  ViewModels/      Per-view @Observable view models (form state, validation)
  Views/           SwiftUI views
  Scanners/        Barcode scanning (AVFoundation-backed UIViewRepresentable)
  OpenFoodFacts/   Networking + models for the Open Food Facts API
```

See [AGENTS.md](AGENTS.md) for conventions and more detail aimed at
AI coding assistants working in this repo.
