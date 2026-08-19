---
id: FX-5
epic: post-testing-fixes
title: Let a logged or planned meal be deleted
status: ready
depends_on: [MK-3]
design_doc: null
---

# FX-5 — Let a logged or planned meal be deleted

## Story

As a user, I want to delete a meal I logged or planned by mistake, so it's
gone from my history/timeline entirely (not just "undone" back to planned).

## Background

**User-reported**: there's no way to delete a meal today.
`MealStore.removeEntry(_ entryID:) -> MealEntry?` already exists and
explicitly returns the removed entry "so a caller can restore pantry stock
when deleting an `.eaten` entry" — but nothing calls it. Deleting is
distinct from `undoMealEaten` (which only transitions `.eaten` →
`.planned`, keeping the entry around) — deleting removes it outright, and
for an `.eaten` entry must still restore whatever pantry stock it
decremented, same precision as undo.

## Scope

- Add a delete affordance (swipe action and/or context menu, matching this
  app's existing patterns — e.g. `PantryStore`'s variant deletion, or
  `TemplatesListView`'s own delete-with-confirmation) on `DayTimelineView`'s
  rows and/or `MealDetailView`.
- For a `.planned` entry: delete just calls `appState.meals.removeEntry` —
  no pantry involvement, since planning never touched stock.
- For an `.eaten` entry: delete needs a new `FoodpointKit.AppState`
  orchestration method that calls `removeEntry` and restores pantry stock
  for its `usesFromPantry` ingredients — reuse the same restore logic
  `undoMealEaten` already has (including the "fully depleted item gets
  re-created" case) rather than duplicating it.
- A confirmation prompt before deleting an `.eaten` entry is worth
  considering (it has a real side effect — pantry stock changes) — use
  judgment on whether a plain swipe action is enough or a confirmation
  alert is warranted, consistent with how destructive actions elsewhere in
  this app are handled.

## Acceptance criteria

- [x] A planned entry can be deleted, disappearing from the timeline
- [x] An eaten entry can be deleted, disappearing from the timeline **and**
      restoring exactly the pantry stock it had decremented
      (`usesFromPantry`-off ingredients unaffected either way)
- [x] `FoodpointKitTests` covers the new orchestration method's pantry
      restoration on delete
- [ ] Manual verification on the physical device: delete both a planned and
      an eaten meal, confirm pantry quantities end up correct in both cases
      — **blocked in the Simulator this session, no physical device
      available; see "Manual verification" below**

## Out of scope

- Bulk delete / multi-select — one meal at a time is enough for now

## Implementation

`FoodpointKit.AppState.deleteMeal(_ entryID:) -> MealEntry?` (in
`Packages/FoodpointKit/Sources/FoodpointKit/AppState.swift`): calls
`meals.removeEntry(entryID)`; a no-op, including no pantry mutation, if
`entryID` isn't known, matching `MealStore.removeEntry`'s own contract. If
the removed entry was `.eaten`, restores pantry stock for its
`usesFromPantry` ingredients via a newly extracted `restorePantryConsumption(for:)`
helper — the exact `consumedAmounts`-precise `pantry.restore` loop
`undoMealEaten` used to have inline, now shared by `undoMealEaten`,
`updateMealIngredients` (reversing its OLD ingredient list), and this new
method, rather than tripling the loop across three methods. A removed
`.planned` entry has no pantry effect, since planning never touched stock.
Either way, sweeps any leftover `consumedAmounts` bookkeeping keyed by the
removed entry's ingredient ids.

Covered by a new `Packages/FoodpointKit/Tests/FoodpointKitTests/MealDeletionTests.swift`
suite (9 tests), matching `MealPantryOrchestrationTests`'/
`MealIngredientEditTests`' style and scope discipline: a planned entry's
deletion never touches pantry; an eaten entry's deletion restores exactly
what was consumed, including the clamped-amount case (restores only what
was actually taken, not the full logged amount) and the
fully-depleted-item-recreation case (a later restore re-creates the
`FoodItem`, same as `undoMealEaten`'s own edge case); `usesFromPantry`-off
ingredients are unaffected on either a planned or an eaten entry's
deletion, including a mix of on/off ingredients on the same entry; deleting
an unknown entry id is a no-op, including calling `deleteMeal` twice on the
same entry (no-op the second time). All existing `MealPantryOrchestrationTests`/
`MealIngredientEditTests` were re-run after extracting `restorePantryConsumption`
and remain green, confirming the refactor didn't change `undoMealEaten`'s/
`updateMealIngredients`'s own behavior.

UI wiring: `DayTimelineView`'s rows gained a "Delete" swipe action and
context-menu item, and `MealDetailView` gained a toolbar "Delete" button —
both call a `requestDelete(_:)` function with the same shape in each view:
a `.planned` entry deletes immediately via `appState.deleteMeal(entry.id)`
(no side effect to warn about); an `.eaten` entry instead shows a
confirmation alert first (`entryPendingDeletion` on `DayTimelineView`,
`isShowingDeleteConfirmation` on `MealDetailView`), matching
`TemplatesListView`'s existing delete-with-confirmation pattern, since its
deletion has a real pantry side effect. `MealDetailView` also calls
`dismiss()` (via `@Environment(\.dismiss)`) after a successful delete,
popping back to the timeline since the entry it displays no longer exists.

Files changed: `Packages/FoodpointKit/Sources/FoodpointKit/AppState.swift`,
`Packages/FoodpointKit/Tests/FoodpointKitTests/MealDeletionTests.swift`
(new), `Foodpoint/Views/DayTimelineView.swift`,
`Foodpoint/Views/MealDetailView.swift`.

Tests: `cd Packages/FoodpointKit && swift test` — **40 tests, all passing**
(31 pre-existing + 9 new `MealDeletionTests`). `PantryKit` (31 tests) and
`MealKit` (75 tests) also re-run, unaffected, both green.

Build: `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
— **BUILD SUCCEEDED**.

## Manual verification — blocked

Reconfirms the same BUG-1 blocker FX-4's own findings section documented,
in the same Simulator session shape: a fresh `AppState` run starts with
zero pantry items and zero meal history, so exercising either delete path
(planned or eaten) first requires acquiring at least one ingredient.
Pantry/history ingredient sources were empty (nothing acquired yet), and
scanning needs a camera the Simulator doesn't have, leaving "Search by
Name" (`ProductSearchView`) as the only remaining acquisition route — and
its text field never accepted focus across multiple attempts (tapping its
on-screen location, confirmed correct via screenshot, followed by a `text`
action left the field showing its placeholder every time; no keyboard ever
appeared). No ingredient could be acquired by any means, so no pantry item
and no meal entry (eaten or planned) could be created to delete.

No physical device was available this session either:
`xcrun xctrace list devices` shows "iPhone von Fabian" listed under
**Devices Offline**, not connected.

What *was* confirmed live: the app builds and launches cleanly on this new
binary, the Meals/Items tabs render correctly with zero data, and the
"Search by Name" sheet itself opens/dismisses correctly — only the actual
text entry into it is blocked, the same specific failure mode FX-4 hit.
Screenshots in this session render at roughly the previously-documented
~2.28x the tool's coordinate space (402x874 points); tap coordinates were
divided by that factor throughout, and non-text-input taps (opening menus,
sheets, Cancel) worked correctly once accounted for.

Given the blocker, correctness for this task rests on the automated
`MealDeletionTests` suite (9 tests, all passing) as the primary signal,
plus code review against `undoMealEaten`'s already-tested `consumedAmounts`
reconciliation pattern, which `deleteMeal` reuses directly (via the shared
`restorePantryConsumption` helper) rather than reimplementing.

## Definition of done

`FoodpointKitTests` green (confirmed — 40 tests passing), docs updated
(`AppState.swift`'s, `DayTimelineView.swift`'s, `MealDetailView.swift`'s,
and `MealStore.swift`'s `removeEntry` bullets in AGENTS.md/README.md),
committed. Manual verification is **not** complete — see "Manual
verification — blocked" above — so `status` stays `ready` rather than
flipping to `done` until a session with working Simulator text input, or an
actual connected physical device, can finish it.
