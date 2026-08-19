---
id: FX-3
epic: post-testing-fixes
title: Make the composition editor's "add another ingredient" vs "finish the meal" actions unambiguous
status: in-progress
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

- [x] A user adding a first ingredient has a clear, low-risk way to add
      another without accidentally finishing the meal
- [x] Finishing a meal (via whatever action ends up meaning "Done") still
      takes exactly one deliberate action — no added friction for the
      common case of composing multiple ingredients and finishing normally
- [ ] Manual verification: compose a meal with 3+ ingredients, confirm the
      flow feels natural and doesn't risk an accidental early finish
      (**blocked** — see Verification notes below)

## Out of scope

- Any other composition-editor behavior (ingredient sources, amount
  editing, completeness signal) — this is scoped to the add-vs-finish
  ambiguity only

## Implementation

Combined two of the Scope's options (both in `MealCompositionEditorView`):

1. **"Add Ingredient" made prominent/central** — moved from a left-aligned
   `Label("Add Ingredient", systemImage: "plus.circle")` bottom-bar item to
   a centered (`Spacer()` on both sides) `.buttonStyle(.borderedProminent)`
   button, so it visually reads as *the* next action instead of a small
   icon in the corner.
2. **Lightweight confirmation on "Done" with exactly one ingredient** —
   the toolbar "Done" button now calls
   `finishOrConfirmIfSingleIngredient()`, which shows a
   `.confirmationDialog("Finish with just 1 ingredient?", ...)` with
   "Finish Meal"/"Keep Adding" options only when `rows.count == 1` — the
   exact moment the reported mix-up tends to happen (right after adding
   the first ingredient). 0 ingredients (nothing to lose) and 2+
   ingredients (a deliberately composed meal) both still finish
   immediately on a single tap, unchanged from before this fix — no added
   friction for the common multi-ingredient case.

## Verification notes

- `xcodebuild ... -destination 'generic/platform=iOS Simulator' build`
  succeeded.
- In the iOS Simulator: confirmed by screenshot that the composition
  editor renders the new centered, prominent "Add Ingredient" button, that
  its menu correctly lists all four sources (From Pantry/From
  History/Scan Barcode/Search by Name), and that the Search and Scan
  sheets both open correctly from it.
- **Could not get any ingredient rows into the composer this session**, so
  the "compose 3+ ingredients then Done" and "add exactly 1 ingredient
  then Done" flows were not exercised end-to-end live:
  - Scan requires a camera, unavailable in the Simulator (shows the
    gray "Align Food Barcode Inside" placeholder, as expected).
  - Search by Name reached the live search-a-licious endpoint (confirmed
    reachable with `curl` from the host shell) but every query tried
    ("milk", "cheese", "nutella") returned "No Matches" in the Simulator,
    consistent with the Simulator process itself lacking network access in
    this sandboxed session — a more severe instance of the repo's
    documented BUG-1 (simulator-specific input/acquisition issues) rather
    than a defect in this change.
  - From Pantry / From History had no data to pick from — this is a fresh
    Simulator install with no prior scans or logged meals, so the
    task-suggested workaround wasn't available either.
  - The Simulator's tap coordinate mapping was also unreliable for plain
    `tap` in this session (`touch_path` with a short hold worked instead)
    — separate from the above, but part of why this took longer than
    expected to even reach the acquisition menus.
- The confirmation-dialog gating (`rows.count == 1`) and the button
  restyling were verified by code review instead: `finish()` is called
  directly for 0 or 2+ rows, and only routes through
  `isShowingSingleIngredientConfirmation` at exactly 1 row.
- Whoever picks this up next: retry manual verification once the
  Simulator has network access (or a physical device is available) —
  add 3+ ingredients via Search or Scan, confirm "Done" finishes
  immediately with no dialog; then start a new meal, add exactly 1
  ingredient, confirm "Done" shows the "Finish with just 1 ingredient?"
  dialog and that "Keep Adding" returns to the editor unchanged.

## Definition of done

Manual verification passed, docs updated if the toolbar/action layout
changes (`MealCompositionEditorView`'s bullet in AGENTS.md/README.md),
committed. **Status left as `ready`, not `done`** — implementation and
docs are complete, but full manual verification is blocked per the notes
above.
