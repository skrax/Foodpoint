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

- [x] A planned entry's ingredients can be edited (add/remove/amount
      change) and the change is saved via `updateEntry`
- [x] An eaten entry's ingredients can be edited the same way, with the
      pantry correctly reconciled — old consumption reversed, new
      consumption applied, exactly (not double-counted, not dropped)
- [x] Editing an eaten entry's `usesFromPantry`-off ingredients never
      touches pantry stock, consistent with logging's existing rule
- [x] `FoodpointKitTests` covers the new orchestration method's pantry
      reconciliation
- [ ] Manual verification on the physical device: edit both a planned and
      an eaten meal's ingredients, confirm pantry quantities end up correct
      in both cases — **blocked in the Simulator this session, see "Manual
      verification" below; never attempted on a physical device**

## Out of scope

- Editing a meal's name/slot/date (see FX-6 for naming) — ingredients only,
  unless bundling name editing in in the same UI turns out to be trivial

## Implementation

`FoodpointKit.AppState.updateMealIngredients(_ entryID:ingredients:)` (in
`Packages/FoodpointKit/Sources/FoodpointKit/AppState.swift`): a no-op for an
unknown `entryID`; for a `.planned` entry, a plain `meals.updateEntry` with
the new ingredient list (no pantry involvement, matching how planning itself
never touches stock); for an `.eaten` entry, restores exactly what was
previously taken for each `usesFromPantry` ingredient on the OLD list (the
same `consumedAmounts`-precise `pantry.restore` call `undoMealEaten` makes),
then decrements `pantry` again for each `usesFromPantry` ingredient on the
NEW list via `pantry.consume` (clamping to zero exactly as `markMealEaten`
does), recording the freshly-consumed amounts in `consumedAmounts` keyed by
the new ingredients' own ids so a later `undoMealEaten` or another edit still
reconciles correctly.

Covered by a new `Packages/FoodpointKit/Tests/FoodpointKitTests/MealIngredientEditTests.swift`
suite (11 tests), matching `MealPantryOrchestrationTests`' style and scope
discipline: planned edits never touch pantry and keep `.planned` status;
eaten edits reconcile old-vs-new consumption exactly, both when the new
amount is larger and when it's smaller; insufficient stock on the new list
still clamps softly (deletes the item, same as `markMealEaten`) and a
subsequent `undoMealEaten` still re-creates it correctly; `usesFromPantry`
off on the old list, the new list, or a mix of ingredients across both is
handled correctly; an unknown `entryID` is a no-op.

UI wiring: `DayTimelineView`'s rows gained an "Edit Ingredients" context-menu
item (`editingEntry` state + `.sheet(item:)`), and `MealDetailView` gained a
toolbar "Edit" button — both reopen `MealCompositionEditorView` via its
existing `initialIngredients`/`title` init parameters, pre-populated with the
entry's current ingredients, and call `appState.updateMealIngredients` in
`onDone` instead of creating a new entry. `MealDetailView` was changed to
take `entryID: MealEntry.ID` and look the entry up live from
`appState.meals.entries` on every render, rather than holding a `MealEntry`
snapshot captured once at push time — otherwise its own "Edit" button's save
wouldn't be reflected until the screen was popped and re-pushed.

Files changed: `Packages/FoodpointKit/Sources/FoodpointKit/AppState.swift`,
`Packages/FoodpointKit/Tests/FoodpointKitTests/MealIngredientEditTests.swift`
(new), `Foodpoint/Views/DayTimelineView.swift`,
`Foodpoint/Views/MealDetailView.swift`.

Tests: `cd Packages/FoodpointKit && swift test` — **31 tests, all passing**
(20 pre-existing `MealPantryOrchestrationTests` + 11 new
`MealIngredientEditTests`). `PantryKit` (31 tests) and `MealKit` (75 tests)
also re-run, unaffected, both green.

Build: `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
— **BUILD SUCCEEDED**.

## Manual verification — blocked

Could not complete the acceptance criterion's end-to-end check (edit a
planned entry's ingredients and an eaten entry's ingredients, confirm pantry
quantities end up correct in both cases) in the Simulator, and had no
physical device available this session to try there instead. Blocker, in
detail — the same BUG-1 this task's brief warned about, reconfirmed here:

- A fresh `AppState` (this session's Simulator run) starts with zero pantry
  items, zero meal history, and zero templates, so exercising either edit
  path first requires acquiring at least one ingredient — pantry/history
  sources are empty, and scanning needs a camera the Simulator doesn't have,
  so "Search by Name" (`ProductSearchView`) was the only remaining route.
- Unlike a prior session's FX-7 attempt (where typed search text at least
  reached the field, just returned zero Open Food Facts matches), in this
  session the search text field never accepted focus at all: tapping its
  visible location (confirmed correct by screenshot — cursor/keyboard never
  appeared) followed by a `text` action left the field showing its
  placeholder ("e.g. banana") every time, across five separate attempts from
  two different entry points (`ItemsView`'s search sheet and
  `MealCompositionEditorView`'s "Search by Name" source). No ingredient
  could be acquired by any means, so no pantry item and no meal entry (eaten
  or planned) could be created to edit.
- Everything **not** gated on typed text input worked correctly and was
  exercised live: the Meals tab renders correctly with zero entries;
  `DayTimelineView`'s "+" `addMealMenu` opens and `MealCompositionEditorView`
  ("New Meal") presents correctly; its own "Add Ingredient" menu (Search by
  Name/Scan Barcode/From History/From Pantry) opens correctly; `Cancel`
  closes each sheet cleanly. This confirms the new UI wiring compiles,
  builds, and renders without crashing, but the actual edit flow — reopening
  `MealCompositionEditorView` pre-populated via `initialIngredients` and
  saving through `updateMealIngredients` — was never exercised against a
  real entry.
- One environment note for a future attempt: this session's screenshots are
  returned at roughly 2.28-2.31x the coordinate space the tool documents
  (402x874 points) — tap coordinates must be divided by that factor from
  what's visually measured in the screenshot image, or taps land on the
  wrong control (confirmed by first mis-tapping the "..." menu button at its
  apparent image position before working out the conversion). A future
  session hitting unexplained mis-taps should check for this before assuming
  a UI regression.

Given the blocker, correctness for this task rests on the automated
`MealIngredientEditTests` suite (11 tests, all passing) as the primary
signal, plus code review against `markMealEaten`/`undoMealEaten`'s
established, already-tested `consumedAmounts` reconciliation pattern, which
`updateMealIngredients` reuses directly rather than reimplementing.

## Definition of done

`FoodpointKitTests` green (confirmed), docs updated (`AppState.swift`'s,
`DayTimelineView.swift`'s, and `MealDetailView.swift`'s bullets in
AGENTS.md/README.md), committed. Manual verification is **not** complete —
see "Manual verification — blocked" above — so `status` stays `ready` rather
than flipping to `done` until a session with working Simulator text input,
or an actual physical device, can finish it.
