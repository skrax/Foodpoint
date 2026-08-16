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

- [ ] Day view shows a totals header with completeness signal
- [ ] Week/month range summary: daily totals, average, trend
- [ ] Meal detail shows nutrition-source provenance mix
- [ ] `ItemDetailView` has a Consumption section
- [ ] Meals tab has a most-consumed list
- [ ] Manual verification across a range containing mixed complete /
      incomplete / planned data

## Out of scope

- Nutrition goals/targets, shopping list (both deferred per meals-feature-design.md §11)

## Definition of done

Manual verification passed; docs updated, including a note that the meals
feature is now feature-complete against its bare-level scope (meals-feature-design.md
§2); committed.
