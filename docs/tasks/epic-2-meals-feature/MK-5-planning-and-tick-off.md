---
id: MK-5
epic: meals-feature
title: Planning and tick-off
status: backlog
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

- [ ] Day timeline screen with date navigation and slot grouping
- [ ] Planned entries visually distinct from eaten ones
- [ ] Tick-off transitions planned → eaten via MK-3's orchestration
      (decrement applied, undo available)
- [ ] Planned entries never affect pantry quantities or today's eaten
      totals until ticked off
- [ ] Soft insufficient-stock signal shown on a planned entry, without
      blocking creation or reserving stock
- [ ] Manual verification: plan a meal for tomorrow, confirm zero effect
      on pantry/today's totals, tick it off, confirm it now behaves like a
      manually logged meal

## Out of scope

- Range summary (MK-6)
- Repeating/scheduled plans, custom slots (both deferred per the design doc)

## Definition of done

Manual verification passed, docs updated, committed.
