---
id: MK-1
epic: meals-feature
title: MealKit core model and aggregation
status: done
depends_on: [PA-5, PA-3]
design_doc: meals-feature-design.md#4-concepts-and-data-model
---

# MK-1 — MealKit core model and aggregation

## Story

As a developer, I want the `MealKit` package created with the meal
model and aggregation logic, fully unit-tested and with **zero dependency
on `PantryKit`**, so the meals feature has a solid, independently testable
foundation before any UI is built.

## Scope

New `Packages/MealKit/` (depends only on `FoodFoundation`):

- `MealTemplate`, `MealEntry`, `TemplateIngredient` (`barcode`,
  `productName`, `productBrand`, `imageURL`, `amount`, `usesFromPantry`),
  `LoggedIngredient` (+ `unitLabel`, `gramsResolved`, `nutritionSnapshot`),
  `MealSlot`, `MealStatus`
- `MealStore` (`@Observable`): template CRUD; entry CRUD (log directly as
  eaten, plan for later, `markEaten` — transitions state and returns the
  finalized entry/delta for the caller to act on, per design doc §4.4 —
  and `undo`); day/range aggregation with completeness reporting (§8.2);
  consumption stats (§9)
- Adding an ingredient snapshots product identity **immediately** via
  `FoodFoundation.ProductLookup.fetch` (§4, §4.3)
- Template instantiation re-resolves nutrition **fresh** via
  `ProductLookup.fetch` rather than reusing a cached value (§4.1)
- `FoodpointKit.AppState` gains `meals: MealStore` (bare integration only
  — no orchestration logic yet, that's MK-3)

## Acceptance criteria

- [x] `Packages/MealKit` builds and tests standalone; **zero import of
      `PantryKit`** anywhere in the target or its test target
- [x] Aggregation across mixed weight- and count-tracked ingredients
- [x] Totals report completeness when ingredients lack nutrition data
- [x] Planned entries excluded from eaten totals, included as a separate
      projection
- [x] Adding an ingredient snapshots product identity immediately;
      browsing history requires no network call for already-added
      ingredients
- [x] Template instantiation re-resolves nutrition fresh, not a stale
      cached value
- [x] `usesFromPantry` seeds from the template's default but is
      independently editable per logged instance
- [x] Consumption rate calculation across a date range, including days
      with no entries
- [x] `AppState.meals: MealStore` exists
- [x] README.md / AGENTS.md updated to describe `MealKit`

## Out of scope

- Any UI
- Pantry orchestration (MK-3)
- Templates promotion UI (MK-4), planning UI (MK-5)

## Definition of done

All `MealKit` tests green, package builds standalone, docs updated,
committed.
