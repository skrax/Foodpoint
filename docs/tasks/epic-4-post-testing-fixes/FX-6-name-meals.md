---
id: FX-6
epic: post-testing-fixes
title: Let a meal be given a real name instead of a hardcoded placeholder
status: in-progress
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

- [x] Composing an ad-hoc meal (today or a future plan) lets the user enter
      a name
- [x] A left-blank name still saves successfully with a sensible fallback,
      rather than blocking the save
- [x] Existing template-instantiated meals keep inheriting the template's
      name, unaffected by this change
- [ ] Manual verification: log a meal named "Chicken Salad," confirm it
      shows that name (not "Ad-hoc Meal") on the timeline and in its detail
      view — **blocked in the Simulator this session, no physical device
      available; see "Manual verification" below**

## Out of scope

- Renaming an already-logged meal after the fact (that's FX-4's "edit"
  territory, or could be folded into it — use judgment on whether it's
  cheap to include there once this field exists)

## Implementation

Placement: rather than adding a name field directly to
`MealCompositionEditorView` (the shared composer), the composer's `onDone`
now stashes the composed ingredients (`pendingComposedIngredients`) and
shows a new lightweight "Name This Meal" alert
(`Foodpoint/Views/NameMealPrompt.swift`, `isShowingNamePrompt`) before the
entry is actually persisted. This was the deliberate choice over touching
the shared editor: `TemplateEditorView` also reuses
`MealCompositionEditorView` purely for ingredient composition, alongside
its own separate name `TextField` for the template itself — a second name
field inside the shared editor would have been redundant/confusing there.

`NameMealPromptModifier` mirrors `RememberMealPromptModifier`'s established
`alert(presenting:)` + `TextField` shape (same file pattern this feature
already uses for naming prompts), but with a single "Save" button rather
than three — unlike the remember prompt (an optional add-on shown *after*
a meal is already logged), this alert **is** the commit point for a meal
that hasn't been saved yet, so there's no separate "back out" affordance to
offer (tapping "Done" in the composer always resulted in an immediate save
before this task too). It was factored into its own file/`ViewModifier`
for two reasons: the usual "keep the host view's diff small" convention
this feature already follows (`RememberMealPrompt.swift`,
`TemplatesListView`, `TemplateEditorView`), and, concretely, because
inlining the alert directly into `DayTimelineView`'s already-long modifier
chain pushed the Swift compiler's type-checker over its complexity budget
("the compiler is unable to type-check this expression in reasonable
time") and broke the build — extracting it into its own `View` extension
fixed that too.

`DayTimelineView.addEntry` gained a `name: String` parameter, trimmed and
falling back to `"Ad-hoc Meal"`/`"Planned Meal"` (matching whichever the
old unconditional default used to be, by day) only when the trimmed result
is empty — a blank name never blocks the save. Template-instantiated
entries are untouched — they still inherit the template's own name via
`logTemplate`/`planTemplate`/`logTemplateAndMarkEaten`, none of which go
through `addEntry` at all.

No new pure logic worth a dedicated unit test: the trim-and-fallback is a
one-line `String.trimmingCharacters` check, the same inline style
`DayTimelineView.saveAsTemplate`'s pre-existing `rememberMealName` handling
already uses without its own test — view-only glue per AGENTS.md's
"don't force it if trivial" guidance.

Files changed: `Foodpoint/Views/DayTimelineView.swift`,
`Foodpoint/Views/NameMealPrompt.swift` (new).

Build: `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
— **BUILD SUCCEEDED** (after extracting `NameMealPrompt.swift` to resolve
the type-checker timeout described above).

## Manual verification — blocked

Same BUG-1 blocker `FX-4`'s and `FX-5`'s own findings sections already
documented, reconfirmed in this session: a fresh `AppState` run starts with
zero pantry items and zero meal history, so reaching the new "Name This
Meal" prompt at all first requires composing a meal with at least one real
ingredient (the composer's "Done" only calls `onDone` — and this task's new
prompt only appears — when `ingredients` is non-empty). Every acquisition
route was tried and confirmed blocked or empty:

- **From Pantry** / **From History**: both correctly show empty-state
  screens ("No History Yet" etc.) — expected on a fresh install, not a bug.
- **Scan Barcode**: opens the camera viewfinder correctly, but the
  Simulator has no real camera to scan a barcode with.
- **Search by Name**: the sheet opens correctly (confirmed via screenshot),
  but its text field never accepted focus or text across several attempts
  — tapping its on-screen location (coordinates confirmed correct by first
  calibrating against an unrelated, definitely-working tap target, the
  "•••" menu button) followed by a `text` action left the field showing
  only its placeholder every time, no keyboard ever appeared.

No physical device was available either: `xcrun xctrace list devices`
lists "iPhone von Fabian" under **Devices Offline**, not connected, this
session.

What *was* confirmed live in the Simulator: the app builds and launches
cleanly on the new binary; the Meals tab's "+" menu, slot picker, and
`MealCompositionEditorView` ("New Meal" composer) all open correctly; its
"Add Ingredient" menu opens with all four sources; canceling the composer
correctly discards it with no residual entry created (confirming the new
`isShowingNamePrompt`/`pendingComposedIngredients` state doesn't leak
across a cancel). Screenshots in this session render at roughly the
previously-documented ~2.29x the tool's coordinate space (402x874 points);
tap coordinates were divided by that factor throughout, and non-text-input
taps (menus, sheets, Cancel) worked correctly once accounted for.

Given the blocker, this task's actual "Name This Meal" alert — its
TextField, its "Save" button, and the resulting entry's name on the
timeline/detail view — could **not** be exercised end-to-end this session.
Correctness rests on code review against the already-established
`RememberMealPromptModifier` pattern this new modifier mirrors, plus the
build succeeding, until a session with working Simulator text input or an
actual connected physical device can finish it.

## Definition of done

Docs updated (`DayTimelineView.swift`'s bullet — including its
`addEntry` doc comment — and a new `NameMealPrompt.swift` bullet, in both
AGENTS.md and README.md), committed. Manual verification is **not**
complete — see "Manual verification — blocked" above — so `status` stays
`ready` rather than flipping to `done` until a session with working
Simulator text input, or an actual connected physical device, can finish
it.
