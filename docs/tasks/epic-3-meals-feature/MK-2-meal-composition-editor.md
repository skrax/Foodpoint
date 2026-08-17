---
id: MK-2
epic: meals-feature
title: Meal composition editor and ingredient acquisition
status: backlog
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

- [ ] Ingredient picker offers all 4 sources
- [ ] Pantry-pick source shows remaining pantry quantities correctly
      without `MealKit` importing `PantryKit`
- [ ] History source shows past ingredients instantly, no network call
- [ ] Scan source reuses the existing camera flow
- [ ] Search source lists Open Food Facts matches by name; picking one
      works the same as scan past that point
- [ ] Each row has an amount field and a "Use from pantry" toggle,
      default on
- [ ] First-time barcode prompts minimal unit setup, scoped to this
      ingredient only
- [ ] Running footer shows nutrition total with completeness signal when
      data is missing
- [ ] Manual verification on simulator/device: build one meal using all 4
      sources

## Out of scope

- Actually saving/logging the meal (MK-3)
- Templates (MK-4), planning (MK-5)

## Definition of done

Manual verification passed on device/simulator; any extractable pure
logic (e.g. completeness calculation) covered by `MealKit` unit tests;
docs updated; committed.
