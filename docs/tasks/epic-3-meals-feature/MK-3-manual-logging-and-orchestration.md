---
id: MK-3
epic: meals-feature
title: Manual logging loop and pantry orchestration
status: in-progress
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

- [x] Logging decrements the pantry only for ingredients with
      `usesFromPantry` on — implemented, unit-tested
      (`markMealEatenDecrementsOnlyPantryIngredients`,
      `mixedTogglesOnlyDecrementOnIngredients`), and confirmed live in the
      Simulator (see Manual verification below).
- [x] Ingredients with `usesFromPantry` off never touch inventory —
      unit-tested (`usesFromPantryOffNeverTouchesInventory`,
      `undoNeverRestoresToggleOffIngredients`).
- [x] Insufficient stock clamps to zero with a soft note rather than
      blocking or going negative — implemented
      (`PantryStore.consume`/`AppState.insufficientStockIngredients`),
      unit-tested, **and confirmed live**: logging an ad-hoc meal with a
      `usesFromPantry`-on ingredient not present in the pantry (i.e. 0
      available) correctly logged the meal as eaten *and* surfaced
      "Insufficient Stock — Not enough pantry stock for Bananas — clamped
      to zero." as a non-blocking alert.
- [x] Undo restores exactly what was decremented, per ingredient —
      unit-tested (`undoRestoresExactDecrement`,
      `undoAfterClampRestoresOnlyActualAmount`). **Not confirmed live** —
      see Manual verification below for why.
- [x] Undoing a meal that fully depleted a pantry item re-creates that
      item correctly (not just a quantity bump on a nonexistent item) —
      unit-tested at both layers (`PantryKitTests.restoreRecreatesFullyDepletedItem`,
      `FoodpointKitTests.undoRecreatesFullyDepletedItem`). **Not confirmed
      live** — see Manual verification below.
- [ ] Manual verification: log a meal from the composition editor, confirm
      pantry quantities update, undo, confirm they're restored exactly —
      **partially blocked, not fully completed**. See "Manual verification"
      below for exactly what was and wasn't confirmed, and why.

## Manual verification (2026-08-17)

**What was confirmed live, in the iOS Simulator (iPhone 17 Pro, iOS 26.5),
via `mcp__Claude_Code_iOS_Simulator__control`:**
- Composed an ad-hoc meal in `MealCompositionEditorView` via the "Search by
  Name" ingredient source (searched "banana", picked "Bananas · Morrisons",
  completed the first-time unit-setup prompt), with "Use from pantry" on
  (the default).
- Tapped "Done" on `MealsView`. The entry appeared in the Meals list as
  "Ad-hoc Meal · Snack · 1 ingredient · ≥ 0 kcal · **Eaten**" — confirming
  `appState.meals.plan` + `appState.markMealEaten(_:)` ran and transitioned
  the entry correctly.
- An **"Insufficient Stock"** alert appeared simultaneously: "Not enough
  pantry stock for Bananas — clamped to zero." — confirming
  `PantryStore.consume` was actually called (found no matching pantry item,
  since none exists — see below — and correctly reported 0 consumed), and
  that `appState.insufficientStockIngredients(for:)` correctly surfaced the
  shortfall as `MealsView`'s soft, non-blocking alert per
  meals-feature-design.md §4.4. Logging itself was never blocked.

**What could not be confirmed live, and why:**

1. **A real "existing pantry stock decrements" scenario.** The only UI path
   into the pantry (`ItemsView`'s "•••" → "Search by Name") hit a
   **separate, pre-existing app bug**, unrelated to this task's code: after
   picking any search result, the app goes to a permanently blank white
   screen. Confirmed with process sampling that the main thread is genuinely
   idle (not deadlocked), and via device logs that UIKit *did* dispatch the
   row's tap gesture, yet `ScannerView.fetchFoodData` (the very next step)
   never fires — no network request to `world.openfoodfacts.org` ever
   appears. Reproduced 3 times across full app relaunches with deliberate
   multi-second pauses between steps (ruling out animation-timing/tooling-
   speed causes). Root cause appears to be `ItemsView`'s two-`@State`-
   variable, `onDismiss`-chained sheet hand-off from `ProductSearchView` to
   `ScannerView(entryPoint: .resolved(barcode:))` — the code's own comment
   already flags this pattern as fragile ("SwiftUI can't reliably show two
   sheets from the same state update"). This is squarely
   `docs/tasks/bugs/BUG-1-first-input-field-hang.md` territory (its own
   spike explicitly couldn't reproduce anything, using a *different* nested-
   sheet shape) — flagged as a follow-up there rather than fixed here, since
   it's pre-existing, unrelated code (from UX-1/PA-3) and out of MK-3's
   scope. `MealCompositionEditorView`'s own "Search by Name" (a *single*-
   sheet flow, no `onDismiss` chaining) does **not** hit this bug — it's how
   the ad-hoc meal above was successfully composed.
   Because of this, no product could be gotten into the pantry via the UI
   this session, so there was no existing stock to demonstrate a real
   (non-clamped) decrement against.
2. **The undo swipe action.** `MealsView`'s `.swipeActions { Button("Undo") { appState.undoMealEaten(entry.id) } }`
   could not be triggered via the Simulator automation tooling despite
   roughly a dozen attempts with varying start/end points, speeds, and
   dwell times (a single `tap`, multiple `touch_path` drags from 300ms to
   1000ms total duration, varying x ranges up to the full row width). This
   looks like a tooling limitation synthesizing iOS's `UISwipeActionsView`
   gesture (known to be one of the harder gestures to script without
   XCUITest's dedicated `swipeLeft()`), not an app defect — the code itself
   is a small, standard, unmodified use of `.swipeActions`, and
   `AppState.undoMealEaten` has full, passing unit coverage
   (`FoodpointKitTests`) for exactly the behaviors this would have
   exercised.

**Net assessment:** the orchestration logic itself (`PantryStore.consume`/
`.restore`, `AppState.markMealEaten`/`.undoMealEaten`) is fully implemented
and unit-tested — 14 `FoodpointKitTests` + 11 new `PantryKitTests` cases, all
green — and the *logging* half of the UI wiring was confirmed working
end-to-end live. The *undo* half of the UI wiring is implemented and code-
reviewed but not confirmed live, blocked by the two issues above, both
outside this task's code. Re-run this manual verification once BUG-1's
sequenced-sheet issue is fixed (unblocks getting a real item into the
pantry) and/or from a physical device or Xcode's own UI testing (unblocks
the swipe gesture).

## Out of scope

- Templates (MK-4), planning (MK-5) — both build on this orchestration
- Fixing the pre-existing `ItemsView` search-selection hang — tracked via
  BUG-1, flagged with a concrete new repro during this task's manual
  verification, but not this task's code to fix

## Definition of done

`FoodpointKit` orchestration unit tests green (per meals-feature-design.md
§14's "FoodpointKit (orchestration only)" list) — **met**. Manual
verification — **partially met**, see above. Docs updated, committed —
met.
