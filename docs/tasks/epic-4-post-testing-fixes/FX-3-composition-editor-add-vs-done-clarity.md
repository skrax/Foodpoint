---
id: FX-3
epic: post-testing-fixes
title: Make the composition editor's "add another ingredient" vs "finish the meal" actions unambiguous
status: ready
depends_on: [MK-2]
design_doc: null
---

# FX-3 — Make "add another ingredient" vs "finish the meal" unambiguous

## Story

As a user composing a meal, I want an obvious way to add another
ingredient, so I don't accidentally finish and save the meal when I meant
to keep adding to it.

## Background

**User-reported**: in `MealCompositionEditorView`, "Add Ingredient" is a
bottom-bar button (bottom-left, `plus.circle`), while "Done" sits in the
top-right toolbar (`.confirmationAction`) and finishes/saves the meal.
After adding the first ingredient, the instinctive next action is to tap
the button in the corner to "close this and add another" — except the
top-right corner button is "Done," which finishes the whole meal instead.
This is a real UX trap, not just an unfamiliarity issue: the two actions
("add more" and "I'm finished") are both single taps, both plausible next
steps after adding one ingredient, and not visually distinguished by
anything other than screen position.

## Scope

Pick a fix that makes the distinction obvious without adding real
friction — some options (use judgment, or combine):

- Move/restyle "Done" so it doesn't read as the obvious next tap after
  adding one ingredient (e.g. de-emphasize it until at least one ingredient
  exists, or require a deliberate action distinct from a single corner tap)
- Make "Add Ingredient" more prominent/central rather than a corner
  bottom-bar item, so it's the more natural next tap
- A lightweight confirmation when "Done" is tapped with only one ingredient
  ("Finish with just 1 ingredient?") — cheap, catches the mistake without
  blocking the common single-ingredient case entirely
- Any other affordance that makes "there are two different corner buttons
  that do very different things" less of a trap

## Acceptance criteria

- [ ] A user adding a first ingredient has a clear, low-risk way to add
      another without accidentally finishing the meal
- [ ] Finishing a meal (via whatever action ends up meaning "Done") still
      takes exactly one deliberate action — no added friction for the
      common case of composing multiple ingredients and finishing normally
- [ ] Manual verification: compose a meal with 3+ ingredients, confirm the
      flow feels natural and doesn't risk an accidental early finish

## Out of scope

- Any other composition-editor behavior (ingredient sources, amount
  editing, completeness signal) — this is scoped to the add-vs-finish
  ambiguity only

## Definition of done

Manual verification passed, docs updated if the toolbar/action layout
changes (`MealCompositionEditorView`'s bullet in AGENTS.md/README.md),
committed.
