---
id: PA-4
epic: package-architecture
title: Extract PantryKit
status: done
depends_on: [PA-2]
design_doc: package-architecture.md#33-pantrykit-new--most-of-todays-appstate
---

# PA-4 — Extract PantryKit

## Story

As a developer, I want the pantry-specific state and CRUD moved out of
`FoodpointKit` into its own `PantryKit` package, depending only on
`FoodFoundation`, so pantry logic is fully decoupled from meal logic
before `MealKit` exists.

## Scope

New `Packages/PantryKit/` (depends on `FoodFoundation` only). Move:

- `Models/FoodItem.swift`
- The pantry slice of today's `AppState` into a new `PantryStore`
  (`@Observable`): `items`, `unitConfigs`, `unitVariants`,
  `nutritionConfigs`, `nutritionVariants`, and every existing CRUD method
  (`addProduct`, `allVariants`/`addUnitVariant`/`updateVariant`/
  `removeVariant`/`makeDefault`, `renameUnitLabel`, the nutrition mirror,
  `setQuantity`, `removeItem`) — unchanged logic, now calling
  `FoodFoundation.ProductLookup.fetch` instead of the old
  `AppState.lookupProduct` extension.

`project.pbxproj` hand-edited per AGENTS.md's package-adding recipe.
Migrate `AppStateTests`' pantry-specific cases → `PantryKitTests`, same
assertions against the renamed types.

**Sequencing note:** the app target will likely not build again until PA-5
also lands (nothing wires `PantryStore` into what the views use yet) —
that's expected. PA-4 and PA-5 are meant to be done back-to-back, even if
tracked as separate tasks.

## Acceptance criteria

- [x] `Packages/PantryKit` builds standalone
- [x] `FoodItem` moved
- [x] `PantryStore` holds all pantry state + CRUD, unchanged logic
- [x] `PantryStore` resolves products via `FoodFoundation.ProductLookup.fetch` —
      moot in practice: nothing in `PantryStore`'s own logic calls a lookup
      (that already fully moved to the app layer/`ScannerView` in PA-2, which
      calls `ProductLookup.fetch` directly and hands `PantryStore.addProduct`
      an already-resolved `Product`). No code added to force this literally.
- [x] `project.pbxproj` updated; package graph resolves — confirmed via a
      full app build: it fails only on the views' now-missing `AppState`
      members (expected, PA-5's job), not on package resolution.
- [x] Tests migrated to `PantryKitTests`, same coverage (20 tests), all passing

Additional cleanup beyond the original scope, needed to keep things green:
`FoodpointKit`'s `AppState.swift` reduced to an empty shell (all content
moved out, none of it duplicated); `FoodpointKitTests` target removed from
`Package.swift` since it had zero source files left and `swift test` hard errors
on an empty target (`swift build` only warns) — it'll return in PA-5 once
there's composition-root logic worth testing again.

**README.md / AGENTS.md intentionally not updated in this task** — they'd
have to describe a deliberately transient, about-to-be-wrong state
(`PantryKit` existing but `AppState` an empty shell nothing uses yet).
Doing one accurate doc pass after PA-5 lands, covering PA-4+PA-5 together,
avoids writing docs that would already be stale a few minutes later.

## Out of scope

- View call-site renames, `FoodpointKit.AppState` wiring — both PA-5

## Definition of done

`PantryKit` package + tests green standalone. App-target build is expected
to be broken until PA-5 lands — don't treat that as a regression on its
own; verify it resolves once PA-5 is also done.
