---
id: PA-4
epic: package-architecture
title: Extract PantryKit
status: backlog
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

- [ ] `Packages/PantryKit` builds standalone
- [ ] `FoodItem` moved
- [ ] `PantryStore` holds all pantry state + CRUD, unchanged logic
- [ ] `PantryStore` resolves products via `FoodFoundation.ProductLookup.fetch`
- [ ] `project.pbxproj` updated; package graph resolves
- [ ] Tests migrated to `PantryKitTests`, same coverage, all passing

## Out of scope

- View call-site renames, `FoodpointKit.AppState` wiring — both PA-5

## Definition of done

`PantryKit` package + tests green standalone. App-target build is expected
to be broken until PA-5 lands — don't treat that as a regression on its
own; verify it resolves once PA-5 is also done.
