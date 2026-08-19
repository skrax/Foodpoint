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

- [x] A first-time user can look at a template row and correctly predict
      what tapping its log affordance will do, without prior explanation
- [x] The chosen affordance is visually/behaviorally consistent with how
      "add a meal" already works elsewhere in the Meals tab (the "+"
      pattern), rather than a one-off icon
- [x] Logging still goes through `AppState.logTemplateAndMarkEaten`
      unchanged — this is a UI-affordance fix, not a change to the
      underlying one-tap-log orchestration
- [ ] Manual verification: from the Templates list, log a template and
      confirm it appears on today's timeline exactly as before — **blocked,
      see "Manual verification" below**

## Out of scope

- Any change to template creation/edit/rename/delete
- Any change to `logTemplateAndMarkEaten`'s own behavior

## Implementation

`TemplateLogButton` no longer wraps its whole `label` in a single `Button`.
`label` is now scoped to the row's descriptive content only (name, slot,
ingredient count); the view itself appends a trailing "+" `Menu` listing
`MealSlot.allCases` (`template.defaultSlot` first, marked "(Usual)"),
mirroring `DayTimelineView.addMealMenu`'s glyph and tap-then-pick-a-slot
shape exactly, per the user's suggestion in Background. Picking a slot
calls the same `log(slot:)` → `AppState.logTemplateAndMarkEaten` path as
before, with the same loading/error-alert state, unchanged. This also
resolves the "Consider whether logging from the Templates list should also
let the user pick a slot" scope item — every slot is now reachable, not
just `template.defaultSlot`. `TemplatesListView.templateRow` was updated to
stop rendering its own trailing `bolt.fill` icon (now owned by
`TemplateLogButton`) and its empty-state copy ("Save a meal as a template
to add it to today from the + menu.") was updated to match.

Files changed: `Foodpoint/Views/TemplateLogButton.swift`,
`Foodpoint/Views/TemplatesListView.swift`.

Build: `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
— **BUILD SUCCEEDED**.

## Manual verification — blocked

Could not complete the acceptance criterion's end-to-end check (log a
template from the Templates list, confirm it lands on today's timeline).
Blocker, in detail:

- A fresh `AppState` (this session's Simulator run) starts with zero
  templates, zero pantry items, and zero meal history, so creating a
  template first requires composing at least one ingredient via search or
  scan (pantry/history sources are empty; scan needs a camera the
  Simulator doesn't have).
- Attempting "Search by Name" (`ProductSearchView`) did fire live network
  requests as text was typed (confirmed by the "No Matches" empty state
  updating to echo whatever was actually queried), but every query —
  including well-known terms like "Milk", "Cheese", and "Nutella" that
  should return many Open Food Facts results — came back with zero
  matches. `curl` to the same Open Food Facts endpoints succeeded (200)
  from this session's Bash tool, so the failure looks specific to the
  Simulator's own network path in this sandboxed environment, not the
  endpoints themselves.
- Independently, simulator touch/text input in this session was severely
  delayed and reordered: taps and typed characters routinely landed several
  actions later than issued, sometimes on the wrong control, and typed text
  arrived interleaved with earlier queued characters (e.g. typing "banana"
  once produced a field reading "Bananabanana"; the field later changed
  content — "Milk", then "Cheese" — with no new tap or text action issued
  in between, just elapsed time). This matches the "Simulator-specific
  input issues" flagged in this task's brief (tracked elsewhere as BUG-1),
  though in this session it wasn't confined to search/scan — basic tab-bar
  navigation and toolbar `Menu` taps were affected too.
- Net effect: no ingredient could be reliably acquired, so no template
  could be created, so `TemplateLogButton`'s new "+" menu was never
  exercised against a real row with an actual tap-to-log-and-land-on-the-
  timeline outcome.

What *was* confirmed working in the Simulator despite the above:
`DayTimelineView`'s own "+" `addMealMenu` (Breakfast/Lunch/Dinner/Snack)
opens correctly; `MealCompositionEditorView` ("New Meal") and its "Add
Ingredient" menu (Search by Name/Scan Barcode/From History/From Pantry)
open correctly; `ProductSearchView` opens and does issue live search
requests. The new `TemplateLogButton` code itself was reviewed by hand
against `DayTimelineView.addMealMenu`'s established pattern and against
`TemplatesListView`'s existing `.swipeActions`/`.contextMenu` wiring, and
compiles/builds cleanly, but has not been exercised live end-to-end.

Re-attempting this verification in a later session should first confirm
Open Food Facts search actually returns results in that Simulator (e.g. by
scanning/searching for a real product before touching this feature at
all) before assuming this change itself is at fault if something looks
wrong.

## Definition of done

Docs updated (`TemplatesListView`/`TemplateLogButton`'s bullets in
AGENTS.md/README.md), committed. Manual verification is **not** complete —
see "Manual verification — blocked" above — so `status` stays `ready`
rather than flipping to `done` until a session with working Simulator
network/input can finish it.
