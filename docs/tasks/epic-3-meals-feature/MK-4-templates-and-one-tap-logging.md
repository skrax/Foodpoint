---
id: MK-4
epic: meals-feature
title: Templates and one-tap logging
status: done
depends_on: [MK-3]
design_doc: meals-feature-design.md#7-templates-and-one-tap-logging
---

# MK-4 — Templates and one-tap logging

## Story

As a user, I want to save a meal I log often as a template, so I can log
it again with one tap instead of rebuilding it from scratch every time.

## Scope

- Meals tab surfaces memorized templates directly
- Tapping one logs it to today at the current slot via MK-3's
  orchestration — no further interaction required
- Template creation, two ways:
  1. **Explicitly**, from a "New Meal" editor (reuses MK-2's composition
     editor)
  2. **Promoted from something already logged** — after logging an ad-hoc
     meal, offer *"Remember this meal?"*, reusing `ScannerView`'s existing
     variant-prompt interaction **verbatim**: name field, "Save Variant" /
     "Just This Once" / "Cancel" shape
- Template management: rename, edit, delete

## Acceptance criteria

- [x] Templates list surfaced prominently in the Meals tab
- [x] Tapping a template logs it to today/current-slot in one tap, pantry
      decremented via MK-3
- [x] "New Meal" template editor reuses MK-2's composition editor
- [x] Logging an ad-hoc meal offers "Remember this meal?" using the
      scanner's Save/Just-This-Once/Cancel prompt shape
- [x] Templates can be renamed, edited, and deleted
- [x] Manual verification: create a template both ways, log via one tap,
      confirm it behaves identically to a manually logged meal

## Out of scope

- Planning (MK-5)

## Definition of done

Manual verification passed, docs updated, committed.

## Manual verification notes (2026-08-18)

Verified end to end in the iOS Simulator (iPhone 17 Pro, iOS 26.5), fresh
launches, both template-creation paths:

- **Explicit "New Meal"**: created a template ("Rename Test") via
  `TemplatesListView`'s "+" → `TemplateEditorView` → name + default slot
  + an ingredient added through the reused `MealCompositionEditorView`
  (search-by-name → weight-tracked unit setup) → Save. Appeared correctly
  in the templates list.
- **"Remember this meal?"**: logged an ad-hoc meal (White Bread, 10g)
  through `MealsView`'s composer with empty pantry stock — the existing
  "Insufficient Stock" alert fired first (proving `markMealEaten`'s
  pantry-decrement path ran and clamped to zero, since there was no stock
  to consume), its "OK" then triggered "Remember This Meal?" (exact
  ScannerView-shape alert — name field, Save Variant/Just This
  Once/Cancel). Naming it and tapping "Save Variant" created "Toast
  Snack" in the templates list.
- **One-tap logging**: tapping a template row (`TemplateLogButton`)
  created a new `.eaten` entry ("Toast Snack", Snack · 1 ingredient · 24
  kcal · Eaten) in the Recent list — confirmed identical in shape/status
  to a manually logged entry, going through the same
  `AppState.logTemplateAndMarkEaten` → `markMealEaten` orchestration
  ad-hoc logging uses.
- **Rename/Edit/Delete**: swipe-to-rename (alert, pre-filled name) and
  swipe-to-delete (confirmation alert) both verified; long-press context
  menu's "Edit" opened `TemplateEditorView` pre-populated with the
  template's current name/slot and its ingredients re-instantiated fresh
  (confirming `MealStore.instantiate` is called on edit, not a frozen
  copy).

**Not directly observed**: a nonzero pantry-quantity decrement from
one-tap logging specifically (i.e. watching a pantry item's count go
down after tapping a template, as opposed to the zero-stock clamp case
above). Attempting to first add stock via `ItemsView`'s own search flow
hit an app-wide input/render hang after selecting a search result — the
same profile as the pre-existing, still-unresolved `BUG-1` (this flow is
unmodified UX-1/UX-2 code, not touched by MK-4). A simulator relaunch
recovered it, consistent with BUG-1's own findings. This specific case
(decrementing an existing pantry item via a one-tap template log) is not
separately covered by an automated test either, but it runs through
`AppState.markMealEaten`'s exact code path, which
`FoodpointKitTests/MealPantryOrchestrationTests.swift` already tests
exhaustively (normal decrement, clamping, per-ingredient toggle, undo,
re-creation-on-full-depletion) via the identical `plan` → `markMealEaten`
sequence `logTemplateAndMarkEaten` uses. Given that shared code path plus
everything else above being verified live, this is considered adequately
covered rather than a genuine gap — but if BUG-1 ever gets a fix, this
specific case is worth a quick live re-check.
