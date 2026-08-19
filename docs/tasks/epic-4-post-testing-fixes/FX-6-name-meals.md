---
id: FX-6
epic: post-testing-fixes
title: Let a meal be given a real name instead of a hardcoded placeholder
status: ready
depends_on: [MK-3]
design_doc: null
---

# FX-6 — Let a meal be given a real name instead of a hardcoded placeholder

## Story

As a user, I want to name my meals something meaningful ("Chicken Salad",
"Protein Shake"), so my meal history and timeline are actually readable
instead of a wall of identical "Ad-hoc Meal" entries.

## Background

**User-reported**: every ad-hoc meal is named "Ad-hoc Meal" — there's no
name field anywhere in the flow. This is a real, literal hardcoded string:
`DayTimelineView.addEntry` passes `name: "Ad-hoc Meal"` (today/past days)
or `name: "Planned Meal"` (future days) to `appState.meals.plan` with no
user input involved. `MealEntry.name` itself is a normal, already-editable
`String` — this is purely a missing UI field, not a model limitation.
Templates already have real names (`TemplateEditorView`'s name
`TextField`) and a template-instantiated entry correctly inherits the
template's name — this gap is specific to ad-hoc (non-template) meals.

## Scope

- Add a name field to `MealCompositionEditorView` (or a lightweight prompt
  at the point of logging/planning, whichever reads better in the existing
  flow) so an ad-hoc meal gets a real, user-chosen name instead of the
  hardcoded placeholder.
- Sensible default/placeholder text is fine (e.g. pre-filling something
  like the current slot's name, or leaving it blank with "Ad-hoc Meal" only
  as a fallback if the user genuinely leaves it empty) — the point is the
  user gets to *change* it, not that a default disappears entirely.
- Existing already-logged entries named "Ad-hoc Meal"/"Planned Meal" don't
  need a migration — this only needs to fix the flow going forward.

## Acceptance criteria

- [ ] Composing an ad-hoc meal (today or a future plan) lets the user enter
      a name
- [ ] A left-blank name still saves successfully with a sensible fallback,
      rather than blocking the save
- [ ] Existing template-instantiated meals keep inheriting the template's
      name, unaffected by this change
- [ ] Manual verification: log a meal named "Chicken Salad," confirm it
      shows that name (not "Ad-hoc Meal") on the timeline and in its detail
      view

## Out of scope

- Renaming an already-logged meal after the fact (that's FX-4's "edit"
  territory, or could be folded into it — use judgment on whether it's
  cheap to include there once this field exists)

## Definition of done

Manual verification passed, docs updated (`MealCompositionEditorView`'s
bullet, and `DayTimelineView.addEntry`'s doc comment which currently
documents the hardcoded names this task removes), committed.
