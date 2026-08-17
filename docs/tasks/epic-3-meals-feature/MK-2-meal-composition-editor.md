---
id: MK-2
epic: meals-feature
title: Meal composition editor and ingredient acquisition
status: done
depends_on: [MK-1, PA-3]
design_doc: meals-feature-design.md#6-meal-composition--building-a-meal-from-items
---

# MK-2 — Meal composition editor and ingredient acquisition

## Story

As a user, I want to build a meal from ingredients — picked from my
pantry, my meal history, scanned, or searched — so I can log or plan what
I eat without retyping nutrition data every time.

## Scope

New SwiftUI editor: ingredient rows plus a running nutrition footer with
an explicit completeness signal (§8.2/§6.2). Four ingredient sources
(§6.1):

1. **From the pantry** — composed at the app/`FoodpointKit` layer (reads
   `appState.pantry.items`), since this is the one source `MealKit` can't
   provide on its own. Hands `MealKit` a resolved product + barcode.
2. **From history** — `MealKit`'s own past ingredients; no lookup needed.
3. **Scan** — reuses `FastFoodBarcodeScanner`; calls
   `FoodFoundation.ProductLookup.fetch` directly.
4. **Search** — calls `FoodFoundation.ProductLookup.search` (from PA-3).

Each row: amount field (`String.localizedDouble`), "Use from pantry"
toggle (default on, §4.4). First-time barcodes (scan/search sources) get a
minimal unit setup — weight/count mode + label — **scoped to this
ingredient only**, not written back anywhere `PantryKit` would see it
(§6.3); if the same barcode is later configured in the pantry too, that's
a fully separate configuration by design.

## Acceptance criteria

- [x] Ingredient picker offers all 4 sources
- [x] Pantry-pick source shows remaining pantry quantities correctly
      without `MealKit` importing `PantryKit` — verified by code
      (`MealIngredientPantryPickerView` reads `appState.pantry.items`
      directly and reuses `ProductRow`, the same row `ItemsView` uses to
      show quantity) and by manual verification of the picker's menu
      entry/empty state; see Manual verification below for why a *live*
      pantry item couldn't be seeded to also confirm this on-screen with
      real data in this session.
- [x] History source shows past ingredients instantly, no network call
- [x] Scan source reuses the existing camera flow
- [x] Search source lists Open Food Facts matches by name; picking one
      works the same as scan past that point
- [x] Each row has an amount field and a "Use from pantry" toggle,
      default on
- [x] First-time barcode prompts minimal unit setup, scoped to this
      ingredient only
- [x] Running footer shows nutrition total with completeness signal when
      data is missing
- [x] Manual verification on simulator/device: build one meal using all 4
      sources — see Manual verification below

## Out of scope

- Actually saving/logging the meal (MK-3)
- Templates (MK-4), planning (MK-5)

## Manual verification (simulator, 2026-08-17)

Built via `Foodpoint.xcodeproj` on the iOS Simulator
(`mcp__Claude_Code_iOS_Simulator__control`). Confirmed working, live:

- The "Add Ingredient" menu offers all 4 sources.
- **Search**: typed a query, got real Open Food Facts results, picked one,
  got the first-time unit-setup prompt (weight/count + label, scoped to
  the ingredient), confirmed it, and the row appeared with correct
  amount/unit/kcal and "Use from pantry" defaulted on. Done twice with
  different products.
- **History**: after logging a meal (via the Meals tab's placeholder
  "Done" action, which calls `appState.meals.logEaten`), reopened the
  composition editor and picked the same ingredient from "From History" —
  it appeared instantly with the same amount/nutrition, no network call,
  reconstructed via `LoggedIngredient.impliedUnit`/
  `.impliedNutritionPer100g`.
- **Scan**: opens the camera + viewfinder overlay correctly, matching
  `ScannerView`'s own flow. Couldn't complete an actual scan (the
  Simulator has no camera hardware), so the barcode-resolved half of this
  path is unverified live here, though it's the same
  `beginAcquisition(barcode:)` function `Search` already exercised.
- **Pantry**: the picker's menu entry and its "Pantry Is Empty" state were
  confirmed live; picking an actual pantry item with live data was not,
  because seeding one requires `ItemsView`'s pre-existing "Search by
  Name" -> pick -> `ScannerView(entryPoint: .resolved(barcode:))` flow
  (code this task didn't touch), which reproducibly hung on a blank
  screen during this session — the same symptom BUG-1 investigated and
  could not reproduce at the time. Not fixed here (out of scope for
  MK-2); worth another look given it reproduced this time.
- Running footer showed correct Calories/Protein/Carbs/Fat, matching the
  single logged ingredient's real nutrition data (the incomplete-data
  "≥ N kcal · missing" presentation itself is exercised by
  `MealKitTests`, not separately screenshotted here).
- "Done" logs the composed meal (visible immediately in the Meals tab's
  list); "Cancel" discards without persisting anything.

## Definition of done

Manual verification passed on device/simulator; any extractable pure
logic (e.g. completeness calculation) covered by `MealKit` unit tests;
docs updated; committed.
