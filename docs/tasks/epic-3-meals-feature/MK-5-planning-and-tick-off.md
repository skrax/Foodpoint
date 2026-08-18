---
id: MK-5
epic: meals-feature
title: Planning and tick-off
status: in-progress
depends_on: [MK-3]
design_doc: meals-feature-design.md#5-entry-lifecycle
---

# MK-5 — Planning and tick-off

## Story

As a user, I want to schedule a meal for a future date and tick it off
once I've actually eaten it, so I can plan ahead without it affecting
today's totals or my pantry until it actually happens.

## Scope

- `.planned` entry creation (future date, same composition editor as
  MK-2/MK-4)
- Day timeline screen (§10): Meals tab home, date navigation, entries
  grouped by slot; planned entries render visually distinct (outlined) from
  eaten ones, with a prominent tick-off affordance
- Tick-off transitions `planned` → `eaten` via the **same** `markEaten`/
  `undo` machinery built in MK-3 — "the same object in different states,"
  not a parallel system (§5)
- Soft "needs 6 eggs, you have 4" signal when a plan exceeds current
  stock, **without reserving/holding inventory** (§12 #5 of the meals
  design)

## Acceptance criteria

- [x] Day timeline screen with date navigation and slot grouping —
      `Foodpoint/Views/DayTimelineView.swift`, now the Meals tab home
      (`MealsView.swift` restructured to a thin host). Verified structurally
      in the Simulator: date nav (chevrons + "Today"/"Tomorrow" label),
      `entriesGroupedBySlot(on:)`-backed sections, day summary header.
- [x] Planned entries visually distinct from eaten ones — implemented (thin
      accent-color outline on planned rows vs. filled eaten rows,
      `DayTimelineView.entryRow(_:)`). Not visually observed with a real
      planned entry in the Simulator this session — see "Manual
      verification" below — but the branch is exercised by the row-building
      code for both statuses and there is no other code path.
- [x] Tick-off transitions planned → eaten via MK-3's orchestration
      (decrement applied, undo available) — `DayTimelineView.tickOff(_:)`
      calls the same `appState.markMealEaten(_:)` MK-3 built, no parallel
      path; eaten rows keep MK-3's swipe-to-undo unchanged. Covered by
      existing `MealPantryOrchestrationTests` (unchanged) plus this task's
      new `stockShortfalls`-specific cases.
- [x] Planned entries never affect pantry quantities or today's eaten
      totals until ticked off — explicitly unit-tested:
      `MealPantryOrchestrationTests.planningNeverTouchesPantry` /
      `.planningNeverAffectsTodaysEatenTotal` (`Packages/FoodpointKit/Tests/FoodpointKitTests/MealPantryOrchestrationTests.swift`).
- [x] Soft insufficient-stock signal shown on a planned entry, without
      blocking creation or reserving stock — `MealStore.stockShortfalls(for:availableQuantity:)`
      (pure, `Packages/MealKit/Sources/MealKit/MealStore.swift`) +
      `AppState.stockShortfalls(for:)` wiring it to `pantry.items`
      (`Packages/FoodpointKit/Sources/FoodpointKit/AppState.swift`).
      Unit-tested in both packages (`DayTimelineQueryTests` in `MealKitTests`,
      new cases in `MealPantryOrchestrationTests`) including that checking
      the signal never mutates pantry state.
- [ ] Manual verification: plan a meal for tomorrow, confirm zero effect
      on pantry/today's totals, tick it off, confirm it now behaves like a
      manually logged meal — **not completed**; see "Manual verification"
      below for exactly what was and wasn't possible to check in the
      Simulator this session, and why.

## Manual verification (2026-08-17)

Build succeeded (`xcodebuild ... -destination 'generic/platform=iOS
Simulator'`), and the following was directly observed working in the
Simulator (iPhone 17 Pro):

- The Meals tab opens on the day timeline (title "Meals", date nav row
  reading "Monday / Today", a "0 kcal" eaten summary, and an empty state).
- The "<"/">" chevrons navigate days correctly, including the
  today/future distinction: navigating to tomorrow correctly showed
  "Tuesday / Tomorrow" and switched the empty-state copy to "Plan a meal
  for this day." (the future-day branch), vs. "Log a meal from your
  pantry..." on today — confirming `isFutureDay` and the
  plan-vs-log branching in `addEntry(ingredients:slot:)` are wired to the
  right condition.
- The "+" toolbar item opens a slot-picker menu (Breakfast/Lunch/Dinner/
  Snack icons and labels) exactly as built, and picking a slot opens
  `MealCompositionEditorView` ("New Meal") with its usual "Add Ingredient"
  menu (Search by Name / Scan Barcode / From History / From Pantry) intact
  — MK-2/MK-3's editor and its four acquisition sources are unmodified and
  still reachable through the new flow.

**What could not be verified**: actually acquiring an ingredient to
compose a plannable meal. This app starts with a fresh, in-memory,
zero-persistence `AppState` (no pantry items, no meal history, and the
Simulator has no camera to scan a real barcode), so "Search by Name" —
`ProductSearchView`'s `.searchable()` field — is the only available
acquisition path for a first ingredient. That field was tapped and typed
into repeatedly, across several coordinate recalibrations and multiple
full app relaunches, and never registered focus or accepted a single
character (placeholder text never changed, no cursor/keyboard appeared) —
while every other tap in the same session (tab switching, toolbar menus,
sheet navigation, nested-sheet presentation, Cancel buttons) worked
correctly once coordinates were converted to the tool's point space
correctly. This exactly matches the symptom `docs/tasks/bugs/BUG-1-first-input-field-hang.md`
already investigated as a spike (that spike's own Simulator session could
not reproduce it and attributed the earlier observation to coordinate-math/
screenshot-lag tooling artifacts) — this session's coordinates were
verified correct via multiple other successful taps at the same computed
scale, and the hang was still 100% reproducible on this specific
`.searchable()` field, both nested inside the composer and standalone from
`ItemsView`'s own "Search by Name" entry point. Per this task's own
instructions not to burn the session chasing a pre-existing, separately-
tracked bug, no further attempts were made; `ProductSearchView`,
`ScannerView`, and `MealCompositionEditorView` are unmodified by this task.

**Net effect**: the day-timeline shell, date navigation, and
plan-vs-log branching were confirmed working end-to-end in the Simulator;
the pantry-decrement/tick-off/undo loop itself was *not* re-confirmed live
(beyond the automated `FoodpointKitTests`/`MealKitTests` coverage above,
which does exercise that exact logic without the UI) because no ingredient
could be added to compose a meal with in this session. A future session
with a working `ProductSearchView` field (or a physical device, or seeded
pantry data) should complete the walk described in the acceptance
criterion above before flipping `status` to `done`.

## Out of scope

- Range summary (MK-6)
- Repeating/scheduled plans, custom slots (both deferred per the design doc)

## Definition of done

Manual verification passed, docs updated, committed. **Not yet met**: the
manual-verification acceptance criterion is unchecked per the section
above — implementation, tests, and docs are otherwise complete. `status`
is left as `backlog` rather than `done` for this reason.
