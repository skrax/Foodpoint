---
id: MK-3
epic: meals-feature
title: Manual logging loop and pantry orchestration
status: backlog
depends_on: [MK-1, MK-2, PA-5]
design_doc: package-architecture.md#35-foodpointkit-shrinks-to-a-composition-root
---

# MK-3 — Manual logging loop and pantry orchestration

## Story

As a user, when I log a meal I ate, my pantry quantities update
automatically for ingredients I marked as "from my pantry" — and I can
undo a mistaken log without losing trust in either my meal history or my
inventory.

## Scope

This is the core loop, end to end. `FoodpointKit.AppState` orchestration
(package-architecture.md §3.5's `markMealEaten` sketch):

```swift
extension AppState {
    public func markMealEaten(_ entryID: UUID) {
        guard let entry = meals.markEaten(entryID) else { return }
        for ingredient in entry.ingredients where ingredient.usesFromPantry {
            pantry.consume(barcode: ingredient.barcode, amount: ingredient.amount)
        }
    }
}
```

- `undo` reverses using the same per-ingredient deltas
- Handles the edge case from package-architecture.md §4.3: undoing a meal
  that fully depleted (and thus deleted, per `PantryStore.setQuantity`'s
  existing zero-quantity guard) a pantry item must **re-create** that item
  using the ingredient's snapshotted product + unit info, not just bump a
  quantity that no longer has anything to bump
- Wires MK-2's composition editor into a real "Save"/"Log" action that
  creates a `.eaten` `MealEntry` and immediately triggers this
  orchestration
- Insufficient stock (toggle on) clamps to zero with a soft inline note,
  per meals doc §4.4 — doesn't block, doesn't go negative

## Acceptance criteria

- [ ] Logging decrements the pantry only for ingredients with
      `usesFromPantry` on
- [ ] Ingredients with `usesFromPantry` off never touch inventory
- [ ] Insufficient stock clamps to zero with a soft note rather than
      blocking or going negative
- [ ] Undo restores exactly what was decremented, per ingredient
- [ ] Undoing a meal that fully depleted a pantry item re-creates that
      item correctly (not just a quantity bump on a nonexistent item)
- [ ] Manual verification: log a meal from the composition editor, confirm
      pantry quantities update, undo, confirm they're restored exactly

## Out of scope

- Templates (MK-4), planning (MK-5) — both build on this orchestration

## Definition of done

`FoodpointKit` orchestration unit tests green (per meals-feature-design.md
§14's "FoodpointKit (orchestration only)" list), manual verification
passed, docs updated, committed.
