---
id: FX-4
epic: post-testing-fixes
title: Let a meal's ingredients be edited after it's logged or planned
status: ready
depends_on: [MK-3]
design_doc: null
---

# FX-4 — Let a meal's ingredients be edited after it's logged or planned

## Story

As a user, I want to fix a meal I already logged or planned — add a missed
ingredient, correct an amount, remove something — without deleting it and
starting over.

## Background

**User-reported**: there's currently no way to change a meal's ingredients
after it's been composed. `MealStore.updateEntry(_ entry:)` already exists
(replaces an entry by `id` in place) but nothing in the UI calls it, and
`DayTimelineView`/`MealDetailView` offer no "Edit" affordance —
`TemplateEditorView` is the only place `MealCompositionEditorView` gets
reopened with `initialIngredients` today, and that's for templates, not
logged/planned entries.

Editing an **`.eaten`** entry is the harder case: its `usesFromPantry`
ingredients already decremented the pantry (MK-3's `markMealEaten`), so
changing ingredients/amounts means reconciling that — the pantry delta
needs to reverse the old ingredients' consumption and (re-)apply the new
ingredients' consumption, the same "restore exactly what was taken, not
naively the full logged amount" precision `undoMealEaten` already has to
get right. Editing a **`.planned`** entry is simpler — nothing's touched
the pantry yet, so it's just `updateEntry` with no orchestration needed.

## Scope

- Add an "Edit" affordance reachable from `MealDetailView` (and/or a
  context menu on `DayTimelineView`'s rows) that reopens
  `MealCompositionEditorView` pre-populated via its existing
  `initialIngredients` init parameter.
- For a `.planned` entry: saving edits just calls
  `appState.meals.updateEntry` directly — no pantry involvement.
- For an `.eaten` entry: saving edits needs a new `FoodpointKit.AppState`
  orchestration method (alongside `markMealEaten`/`undoMealEaten`) that
  reverses the old ingredient list's pantry consumption and applies the new
  list's, using the same clamp-to-zero/soft-note and
  fully-depleted-item-recreation logic `consume`/`restore` already have —
  don't reimplement that logic, reuse it.
- Cover the new orchestration method with `FoodpointKitTests`, matching
  `MealPantryOrchestrationTests`' existing style.

## Acceptance criteria

- [ ] A planned entry's ingredients can be edited (add/remove/amount
      change) and the change is saved via `updateEntry`
- [ ] An eaten entry's ingredients can be edited the same way, with the
      pantry correctly reconciled — old consumption reversed, new
      consumption applied, exactly (not double-counted, not dropped)
- [ ] Editing an eaten entry's `usesFromPantry`-off ingredients never
      touches pantry stock, consistent with logging's existing rule
- [ ] `FoodpointKitTests` covers the new orchestration method's pantry
      reconciliation
- [ ] Manual verification on the physical device: edit both a planned and
      an eaten meal's ingredients, confirm pantry quantities end up correct
      in both cases

## Out of scope

- Editing a meal's name/slot/date (see FX-6 for naming) — ingredients only,
  unless bundling name editing in in the same UI turns out to be trivial

## Definition of done

`FoodpointKitTests` green, manual verification passed on the physical
device, docs updated, committed.
