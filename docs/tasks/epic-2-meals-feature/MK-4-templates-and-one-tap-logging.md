---
id: MK-4
epic: meals-feature
title: Templates and one-tap logging
status: backlog
depends_on: [MK-3]
design_doc: meals-feature-design.md#7-templates-and-one-tap-logging
---

# MK-4 — Templates and one-tap logging

## Story

As a user, I want to save a meal I log often as a template, so I can log
it again with one tap instead of rebuilding it from scratch every time.

## Scope

- Meals tab surfaces memorized templates directly
- Tapping one logs it to today at the current slot via MK-3's
  orchestration — no further interaction required
- Template creation, two ways:
  1. **Explicitly**, from a "New Meal" editor (reuses MK-2's composition
     editor)
  2. **Promoted from something already logged** — after logging an ad-hoc
     meal, offer *"Remember this meal?"*, reusing `ScannerView`'s existing
     variant-prompt interaction **verbatim**: name field, "Save Variant" /
     "Just This Once" / "Cancel" shape
- Template management: rename, edit, delete

## Acceptance criteria

- [ ] Templates list surfaced prominently in the Meals tab
- [ ] Tapping a template logs it to today/current-slot in one tap, pantry
      decremented via MK-3
- [ ] "New Meal" template editor reuses MK-2's composition editor
- [ ] Logging an ad-hoc meal offers "Remember this meal?" using the
      scanner's Save/Just-This-Once/Cancel prompt shape
- [ ] Templates can be renamed, edited, and deleted
- [ ] Manual verification: create a template both ways, log via one tap,
      confirm it behaves identically to a manually logged meal

## Out of scope

- Planning (MK-5)

## Definition of done

Manual verification passed, docs updated, committed.
