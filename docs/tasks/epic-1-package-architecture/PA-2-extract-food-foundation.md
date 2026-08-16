---
id: PA-2
epic: package-architecture
title: Extract FoodFoundation
status: backlog
depends_on: [PA-1]
design_doc: package-architecture.md#32-foodfoundation-new
---

# PA-2 — Extract FoodFoundation

## Story

As a developer, I want the shared, stateless "nouns" pulled out of
`FoodpointKit` into a new `FoodFoundation` package, so `PantryKit` and
`MealKit` can each depend on them without depending on each other.

## Scope

New `Packages/FoodFoundation/` (depends on `OpenFoodFactsKit`, platforms
`.iOS(.v16)`/`.macOS(.v12)` — no `@Observable` here, so no need for the
`.v17`/`.v14` Observation minimum). Move from `FoodpointKit`:

- `Models/Product.swift` — `Product`, `Nutrition` (`scaled(by:)`,
  `isEffectivelyEmpty`, `isApproximatelyEqual`)
- `Models/ProductUnit.swift` — **type only**: `ProductUnit`,
  `UnitTrackingMode`, `.make(...)`. Variant CRUD does *not* move (PA-4).
- `Models/NutritionVariant.swift` — **type only**: `NutritionVariant`,
  `NutritionSource`. Variant CRUD does *not* move (PA-4).
- `Models/FoodCategory.swift`
- `Models/NumericInput.swift` (`String.localizedDouble`)
- `ProductMapping.swift` → rename to `ProductLookup.swift`:
  ```swift
  public enum ProductLookup {
      public static func fetch(barcode: String) async throws -> Product {
          let offProduct = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
          return Product(offProduct: offProduct)
      }
  }
  ```
  (`.search` arrives in PA-3.)

`FoodpointKit`'s `Package.swift` depends on `FoodFoundation` instead of
`OpenFoodFactsKit` directly. `project.pbxproj` hand-edited per AGENTS.md's
"Adding a new package dependency" recipe.

Migrate tests: `ProductUnitTests`, `NutritionTests`, `FoodCategoryTests`,
`NumericInputTests`, `ProductMappingTests` → new `FoodFoundationTests`
target, same assertions.

## Acceptance criteria

- [ ] `Packages/FoodFoundation` builds standalone (`swift build`)
- [ ] All six items above moved; `FoodpointKit` no longer contains them
- [ ] `ProductLookup.fetch` implemented and used everywhere the old
      `AppState.lookupProduct` extension was
- [ ] `project.pbxproj` updated; app builds (simulator + device)
- [ ] Tests migrated to `FoodFoundationTests`, all passing
- [ ] `FoodpointKitTests` updated (migrated files removed), still passing
- [ ] README.md / AGENTS.md updated to describe the new package

## Out of scope

- `PantryKit` extraction (PA-4)
- Search capability (PA-3)

## Definition of done

Full app build + all tests green, docs updated, committed.
