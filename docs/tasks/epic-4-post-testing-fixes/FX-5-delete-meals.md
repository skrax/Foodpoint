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

- [ ] A planned entry can be deleted, disappearing from the timeline
- [ ] An eaten entry can be deleted, disappearing from the timeline **and**
      restoring exactly the pantry stock it had decremented
      (`usesFromPantry`-off ingredients unaffected either way)
- [ ] `FoodpointKitTests` covers the new orchestration method's pantry
      restoration on delete
- [ ] Manual verification on the physical device: delete both a planned and
      an eaten meal, confirm pantry quantities end up correct in both cases

## Out of scope

- Bulk delete / multi-select — one meal at a time is enough for now

## Definition of done

`FoodpointKitTests` green, manual verification passed on the physical
device, docs updated, committed.
