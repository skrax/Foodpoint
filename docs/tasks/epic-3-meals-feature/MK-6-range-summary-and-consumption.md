---
id: MK-6
epic: meals-feature
title: Range summary and consumption surfaces
status: backlog
depends_on: [MK-3]
design_doc: meals-feature-design.md#8-nutrition-aggregation-over-a-timespan
---

# MK-6 — Range summary and consumption surfaces

## Story

As a user, I want to see my nutrition totals over a day or a longer range,
and see which products I actually consume, so I can evaluate my eating
patterns and know what's worth restocking.

## Scope

- Day view totals header: completeness signal (§8.2) and a
  planned-projection line ("eaten 1,240 kcal · planned +610", §8.1) —
  benefits from MK-5 for the planned figure, but degrades gracefully to
  "eaten only" if MK-5 isn't done yet
- Week/month range summary: daily totals, average, simple trend —
  *description*, not evaluation (no goals/targets — deferred, §11)
- Meal detail shows nutrition-source provenance mix (Open Food Facts vs.
  Custom, §8.3)
- `ItemDetailView` gains a **Consumption** section: last eaten, times
  eaten, total amount over the last 30 days (§9) — reuses this existing
  screen rather than adding a new one
- Meals tab gains a most-consumed list across all products

## Acceptance criteria

- [x] Day view shows a totals header with completeness signal
      (`DayTotalsHeaderView`, above `MealsView`'s entry list)
- [x] Week/month range summary: daily totals, average, trend
      (`RangeSummaryView`, over `MealStore.rangeSummary`/`.caloricTrend`)
- [x] Meal detail shows nutrition-source provenance mix
      (`MealDetailView`, over `MealStore.provenanceMix(for:)`)
- [x] `ItemDetailView` has a Consumption section (last eaten/times
      eaten/30-day total, via `appState.meals.consumptionStats`)
- [x] Meals tab has a most-consumed list (`MostConsumedView`, over
      `MealStore.mostConsumed`)
- [ ] Manual verification across a range containing mixed complete /
      incomplete / planned data — **blocked, see note below**

## Out of scope

- Nutrition goals/targets, shopping list (both deferred per meals-feature-design.md §11)

## Definition of done

Manual verification passed; docs updated, including a note that the meals
feature is now feature-complete against its bare-level scope (meals-feature-design.md
§2); committed.

**Status: blocked on manual verification, not done.** All five scope items
are implemented, covered by new/extended `MealKitTests` (all green — see
below), and the full app builds clean
(`xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
succeeds). Docs (README.md, AGENTS.md) are updated, including the §2
feature-completeness note this task's own DoD asks for.

What blocked manual verification: this session repeatedly hit **BUG-1**
(`docs/tasks/bugs/BUG-1-first-input-field-hang.md`) — taps and typed text
stopped registering in the Simulator, reproduced on totally untouched
screens (the Items tab's tab-bar buttons, `ProductSearchView`'s search
field) that this task never modified, so it isn't something this change
introduced. Tried, in order, all still hanging: relaunching the app twice,
a full `xcrun simctl shutdown`/`boot` of the device, and a clean
`simctl uninstall`/`install`/`launch`. Also discovered along the way that
this Simulator device is shared across the three parallel MK-4/MK-5/MK-6
worktree sessions — an old, different agent's build (showing an actual day
timeline UI, presumably MK-5's) was still installed and briefly visible
before a clean reinstall confirmed which build was actually running.

What *was* verified: the empty-state Items/Meals tabs render without
crashing on a fresh launch, and — separately — a `DayTotalsHeaderView`
render was visually confirmed via the "Eaten 0 kcal" line showing correctly
on an empty store, before input stopped registering again. Populating
pantry/meal data to exercise the requested "mixed complete / incomplete /
planned" scenario (which needs `ProductSearchView`'s search field or the
camera scanner, both currently unusable in this Simulator session) could
not be completed. Whoever merges this branch should re-run manual
verification in a fresh Simulator session before flipping `status` to
`done`.
