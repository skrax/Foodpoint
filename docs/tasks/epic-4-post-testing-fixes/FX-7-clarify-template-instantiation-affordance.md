---
id: FX-7
epic: post-testing-fixes
title: Make logging a template from the Templates list self-explanatory
status: ready
depends_on: [MK-4]
design_doc: null
---

# FX-7 — Make logging a template from the Templates list self-explanatory

## Story

As a user browsing my saved templates, I want it to be obvious that tapping
a template logs it to today right now, so I'm not surprised by what a
lightning-bolt icon actually does.

## Background

**User-reported**: in `TemplatesListView`, each row's one-tap-log control
(`TemplateLogButton`) is a `bolt.fill` icon — nothing about "a lightning
bolt" communicates "logs this meal to today at the current slot right
now." The user's own suggestion: logging a template should work the same
way adding an ad-hoc meal does — via a "+"-style affordance, matching the
"+" the day timeline already uses for composing a new meal
(`DayTimelineView.addMealMenu`), so the interaction language is consistent
across the app rather than introducing a different icon/metaphor just for
templates.

## Scope

- Replace (or restructure) the templates list's one-tap-log affordance so
  it reads as "add this to today" rather than an unexplained bolt icon —
  strongly consider reusing a "+" glyph/placement consistent with
  `DayTimelineView`'s own "+" menu, per the user's suggestion.
- Consider whether logging from the Templates list should also let the
  user pick a slot (rather than always defaulting to
  `template.defaultSlot`) — `TemplateLogButton`/`AppState.logTemplateAndMarkEaten`
  already accept a `slot` parameter, so this may be a small addition once
  the affordance itself is reworked. Use judgment on whether this is
  in-scope now or worth a quick follow-up instead — don't let it block the
  core clarity fix.
- `TemplateLogButton`'s existing loading/error-state handling should carry
  over unchanged regardless of what triggers it.

## Acceptance criteria

- [ ] A first-time user can look at a template row and correctly predict
      what tapping its log affordance will do, without prior explanation
- [ ] The chosen affordance is visually/behaviorally consistent with how
      "add a meal" already works elsewhere in the Meals tab (the "+"
      pattern), rather than a one-off icon
- [ ] Logging still goes through `AppState.logTemplateAndMarkEaten`
      unchanged — this is a UI-affordance fix, not a change to the
      underlying one-tap-log orchestration
- [ ] Manual verification: from the Templates list, log a template and
      confirm it appears on today's timeline exactly as before

## Out of scope

- Any change to template creation/edit/rename/delete
- Any change to `logTemplateAndMarkEaten`'s own behavior

## Definition of done

Manual verification passed, docs updated (`TemplatesListView`/
`TemplateLogButton`'s bullets in AGENTS.md/README.md), committed.
