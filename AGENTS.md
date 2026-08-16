# AGENTS.md

Guidance for AI coding assistants working in this repo. See
[README.md](README.md) for a general project overview.

## What this is

Foodpoint is a solo-developer SwiftUI iOS prototype: a pantry inventory
tracker where users scan barcodes to add food items to named locations,
with product/nutrition data fetched from the Open Food Facts API. It is
early-stage — prefer small, direct changes over speculative abstractions.

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
practical, running the app in the simulator.

## Project structure & conventions

The Xcode project uses **file-system synchronized groups**
(`PBXFileSystemSynchronizedRootGroup`), meaning files added under
`Foodpoint/` on disk are picked up automatically — no `.pbxproj` editing
needed when adding a new file.

- `Foodpoint/State/` — Global, app-wide state. `AppState` is an
  `@Observable` singleton (`AppState.shared`) accessed via
  `@Environment(AppState.self)`. Keep this for state genuinely shared
  across views (e.g. the list of locations); don't route local/form state
  through it.
- `Foodpoint/ViewModels/` — One `@Observable` class per view that needs
  local state, validation, or non-trivial logic (e.g.
  `CreateLocationFormViewModel`). Views hold the view model with
  `@State private var viewModel = ...`. Simple, stateless views don't need
  one.
- `Foodpoint/Views/` — SwiftUI views. Keep view bodies declarative; push
  validation/business logic into a view model rather than free functions
  or inline closures.
- `Foodpoint/Scanners/` — Barcode scanning. Wraps `AVFoundation`
  (`AVCaptureSession`) directly via `UIViewRepresentable`; not a SwiftUI-
  native camera API.
- `Foodpoint/OpenFoodFacts/` — Networking (`OpenFoodFactsService`, a
  singleton using `async/await` + `URLSession`) and Codable response
  models for the Open Food Facts v2 API. Errors surface as
  `OpenFoodFactsError`.

## Style notes

- No comments explaining *what* code does — only *why*, for non-obvious
  constraints (see `OpenFoodFactsService`'s User-Agent header, required by
  Open Food Facts' terms of service).
- Prefer editing/extending existing files over introducing new
  abstractions or dependencies. This is a small prototype; don't add
  frameworks, DI containers, or layers it doesn't need yet.
