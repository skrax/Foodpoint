---
id: BUG-1
epic: bugs
title: Investigate first-use input-field hang (spike)
status: ready
depends_on: []
design_doc: null
---

# BUG-1 — Investigate first-use input-field hang (spike)

## Story

As a user, the first time I interact with certain input fields, the app
appears to hang or not register input — I want this understood (and fixed,
if it's real) so text entry is reliable everywhere, not just after the
first attempt.

## Background

Two independent reports point at the same symptom:

- **User-reported**, verbatim: "the first time you use an input field the
  app hangs / doesn't recognize it."
- **Observed by Claude** while manually verifying UX-1/PA-3 through the
  iOS Simulator: interacting with `ProductSearchView`'s `.searchable()`
  field repeatedly caused *all* subsequent touch input across the app to
  stop registering — reproduced across multiple full Simulator reboots.
  At the time this was written off as a Simulator/automation-tooling
  artifact rather than a real app bug, specifically because it seemed tied
  to the automated control surface used for testing. **The user's separate
  report undercuts that assumption** — if it's also happening through
  normal interaction (not just scripted taps), it may be a genuine app
  bug, not a tooling quirk. That's exactly what this spike needs to settle.

This is filed as a **spike** (time-boxed investigation) rather than a
standard fix ticket because the root cause isn't known yet — it could be a
`.searchable()`/`@FocusState` first-responder timing issue, something
specific to this app's view hierarchy, a genuine Simulator limitation, or
something else entirely.

## Scope

- Reproduce (or explicitly rule out) on the **physical device**, not just
  the Simulator — the strongest signal for whether this is app-real or
  tooling-only.
- Narrow the trigger down:
  - Does it affect only `.searchable()` fields (`ProductSearchView`), or
    plain `TextField`s too (e.g. the package-weight field in `ScannerView`,
    nutrition value fields in `NutritionVariantEditForm`)?
  - Does it happen on the *first* field interacted with per app
    launch/session specifically, or on the first use of *each* field
    (i.e. does it recur per-field, or only ever once per launch)?
  - Any correlation with how the field's containing view was presented
    (tab root vs. sheet vs. nested sheet)?
- If a root cause is found, fix it. If not, document what's known/unknown
  precisely enough that a follow-up ticket could pick it up without
  re-deriving this investigation from scratch.

## Acceptance criteria

- [ ] Reproduced or explicitly ruled out on the physical device
- [ ] Determined whether this is specific to `.searchable()` or general to
      all `TextField`s
- [ ] Determined whether it's a once-per-launch thing or recurs per-field
- [ ] Either: a root cause is identified and fixed, **or**: findings are
      written up here precisely enough to hand off, with a follow-up
      ticket filed if more investigation/work is still needed

## Out of scope

- Fixing every downstream consequence of the bug speculatively before the
  root cause is understood — this is diagnosis-first

## Definition of done

Findings documented in this file (updated in place once known), fix
applied and verified if one was found and is small enough to land as part
of this spike, committed. If the fix is larger than a spike-sized change,
stop at documented findings + a follow-up ticket instead of scope-creeping
into a bigger fix here.
