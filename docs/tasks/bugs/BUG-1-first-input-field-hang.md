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

- [ ] Reproduced or explicitly ruled out on the physical device — **not
      completed**; no physical-device tooling was available to this spike
      (Simulator-only). Still needs the user to confirm on-device. See
      Findings below.
- [x] Determined whether this is specific to `.searchable()` or general to
      all `TextField`s — general question doesn't apply: no hang of any
      kind was reproduced for either field type in the Simulator. See
      Findings.
- [x] Determined whether it's a once-per-launch thing or recurs per-field —
      same caveat: nothing hung in the Simulator across many fields, many
      sheets, and several separate launches, so "once-per-launch vs.
      recurs" couldn't be observed either way here.
- [x] Either: a root cause is identified and fixed, **or**: findings are
      written up here precisely enough to hand off, with a follow-up
      ticket filed if more investigation/work is still needed — no root
      cause found (nothing reproduced); findings below.

## Findings (spike investigation, 2026-08-17)

**Summary: no input hang was reproduced anywhere in the iOS Simulator**,
despite deliberately exercising every combination the Scope section calls
out — `.searchable()` and plain `TextField`s, first-use and repeated use,
and tab-root/sheet/nested-sheet/pushed+sheet presentation contexts, all in
one continuous app session plus several fresh launches. Tooling used:
`mcp__Claude_Code_iOS_Simulator__control` (attach/launch/tap/text/
screenshot) driving a Debug build on iPhone 17 Pro, iOS 26.5 Simulator,
built via the standard `xcodebuild ... -destination 'generic/platform=iOS
Simulator'` command from AGENTS.md. Physical-device testing was out of
reach for this spike — see "What's still unknown" below.

### What was tested, and confirmed working

All of the following were driven with real taps + injected keystrokes
(not just code review), and each produced the expected result with no
loss of touch responsiveness before, during, or after:

1. **`.searchable()` field, tab-root presentation**: Scan tab (root,
   `entryPoint == nil`) → "Search by Name" button → `ProductSearchView`
   sheet → typed into the search field, submitted, got live results back
   from Open Food Facts, selected one, `ScannerView.fetchFoodData`
   resolved it correctly.
2. **`.searchable()` field, *nested*-sheet presentation** (the specific
   shape flagged as suspicious in the Background section —
   `ItemsView`'s "•••" menu → `ScannerView(entryPoint: .search)` sheet →
   `triggerEntryPointIfNeeded()` immediately opens `ProductSearchView` as
   a second, nested sheet on `.onAppear`): typed into the search field
   here too, no issue. This was the exact mechanism most worth
   suspecting for a first-responder race (sheet presenting another sheet
   synchronously on appear) and it did not reproduce a hang.
3. **Plain `TextField`s in `ScannerView.unitConfigFields`** (package
   weight, count label, count-per-package — none of them `.searchable()`,
   all plain `TextField` + `.focused($focusedUnitField, ...)`): focused
   and typed into all three in sequence, switching focus between them
   repeatedly. All accepted input and updated `@State` correctly (the
   derived "≈ 500 g per item" hint recomputed live, proving the binding
   round-tripped).
4. **The full save flow**: saved the product, which triggers
   `scanAgain()` → reopens the camera sheet → swiped it away → landed
   back on the tab bar, still fully responsive.
5. **A third field type/context, three presentation layers deep**:
   `ItemsView` → push to `ItemDetailView` → "Nutrition" → sheet
   (`NutritionVariantsView`) → "+" → another sheet
   (`NutritionVariantEditForm`) → typed into its numeric `Calories`
   `TextField`. Worked immediately.
6. **Repeated/first-vs-Nth use**: none of the above was "first field
   works, second one hangs" — the single continuous session above hit
   six or seven distinct fields across four distinct views/sheets in a
   row with no degradation. Also tested fresh app launches (terminate +
   relaunch) multiple times; first-tap-after-launch worked fine once
   pointed at the right coordinates (see below).

### A concrete, mundane explanation for the *previous* "Simulator hang" observation

While driving the Simulator for this spike, I initially reproduced
something that looked exactly like the previously-reported symptom: taps
on the tab bar, toolbar buttons, and fields appeared to do nothing at all,
repeatedly, immediately after a fresh launch. Investigating that (process
sampling via `sample`, confirming the app's main thread was idle in
`mach_msg`/`CFRunLoopRun` — i.e. genuinely waiting for input, not
deadlocked or spinning) turned up two mundane, tooling-side causes, not
an app bug:

- **My own coordinate math was wrong.** The control tool's tap/swipe
  coordinates are in *points* (this device: 402×874), but I was
  eyeballing target positions directly off the screenshot images, which
  render at roughly 2.28x that (i.e. pixel, not point, scale). Points I
  computed without consistently dividing back down by that factor landed
  outside the valid coordinate space (e.g. y=1213 against an 874-point-
  tall screen) or on the wrong element entirely, and the tool silently
  no-ops on an out-of-range/miss tap rather than erroring — which looks
  identical to "the app stopped responding" if you don't cross-check.
  Once coordinates were correctly converted, every tap landed and worked,
  including ones at the exact same logical target (e.g. the Scan tab)
  that had appeared to fail moments earlier.
- **`screenshot` can lag one call behind actual on-screen state**,
  observed directly once in this session: after `launch` reported success
  and a `tap` had already been delivered and acted on (confirmed by the
  *next* screenshot), an intermediate `screenshot` call still showed the
  previous app (Settings) as frontmost. Anyone driving the Simulator via
  this tool and trusting each screenshot as ground-truth-at-that-instant
  could easily conclude input had stopped working when it's actually the
  observation channel that's stale.

Both of these apply directly to the "Claude's own repeated observation"
half of this bug's Background — they're a plausible, complete explanation
for it that doesn't require any defect in `ProductSearchView`,
`ScannerView`, `@FocusState`, or `.searchable()`. This matches (and now
has concrete evidence for) the original write-off as a "Simulator/
automation-tooling artifact."

### What's still unknown

The **user's independent report via normal (non-scripted) interaction**
is the part this spike could not address and does not explain — the
coordinate-math and screenshot-lag issues above are specific to
driving the Simulator programmatically through this control tool; they
have no equivalent for a person directly tapping the screen (whether in
the Simulator with a mouse, or on a physical device with a finger). It's
possible the user was using the Simulator directly (in which case a
present-but-different Simulator-only issue is still on the table, just
not one this session could trigger despite deliberately trying many
presentation shapes), or a physical device (in which case this spike has
no data either way — no physical-device tooling was available in this
environment, only `mcp__Claude_Code_iOS_Simulator__control`, which is
Simulator-only).

One structural note from code review, not a confirmed bug: `ScannerView`
does synchronously trigger a second sheet presentation from inside
`.onAppear` (`triggerEntryPointIfNeeded()`, `ScannerView.swift`) when
entered via `entryPoint`, and `scanAgain()` re-triggers the same sheet
immediately after a save. Sheet-presents-sheet-synchronously-on-appear is
a known category of SwiftUI/UIKit first-responder timing footgun on real
devices in some iOS versions (differs from Simulator in animation/
Core Animation display-link timing), even though it didn't reproduce
here. If the user hits the hang again, worth checking whether it
correlates with exactly this transition (opening search/scan from the
Items "•••" menu) vs. the Scan tab's own root button (which does the same
`isShowingSearch = true` but from a plain button tap, not from
`.onAppear`).

### Recommended follow-up (not filed as a separate ticket — captured here per the Definition of Done)

If/when the user hits this again on a physical device, the most useful
things to capture before it's dismissed or the app is force-quit:
- Which exact field and which screen/entry path (Scan tab root vs. Items
  "•••" menu vs. somewhere else).
- Whether it's the very first field touched that session, or a field
  touched after some other field already worked.
- Whether *all* touches stop (like the Simulator symptom originally
  described) or just that one field stops accepting text while other
  taps still work.
- Ideally a screen recording — the Simulator-side investigation above
  shows how easy it is to misjudge "did this actually not respond" from
  a single static observation.

Without at least one of those data points from a real device, there's
nothing further to narrow down from code alone — the code paths involved
(`.searchable()`, `.focused()`, plain `TextField` bindings, nested sheet
presentation) all behaved correctly under direct testing here.

### Additional data point (2026-08-19, from FX-1/FX-2 manual verification)

While attempting Simulator-based manual verification for FX-1 (blank
screen after search acquisition) and FX-2 (camera reopening after a
search-originated save) — both landed in the same session, both touching
this exact `ItemsView` "•••" menu → sheet-handoff area — the same class of
tooling flakiness reproduced again, with a new, more specific symptom than
either of the two mundane causes already documented above (bad coordinate
math; a stale `screenshot` lagging one call behind).

This time, coordinates were double-checked against a fully-rendered menu
screenshot before every tap (confirmed correct — one attempt using the
identical technique did work, opening the camera via "Scan Barcode"), yet
repeated subsequent taps on menu items produced no visible effect *at the
time*, and then, several tool calls later with no further taps issued, a
tap fired against whatever the app happened to be showing by then —
landing on a completely unrelated screen (a "New Meal" ingredient
composition view reached via the Meals tab) rather than anything requested
in that turn. The most consistent explanation is that some taps are being
*queued* by the tool/Simulator rather than delivered (or dropped)
immediately, and later flushed against whatever UI is on-screen at flush
time rather than the UI that was on-screen when the tap was issued — a
third, previously-undocumented tooling artifact in this same family as the
first two, and arguably worse for diagnosis since it doesn't just look
like "nothing happened," it looks like "something happened, just not what
I asked for."

This doesn't change this spike's conclusion — still no evidence of a real
app-level input hang, and still nothing that would explain the user's
original non-scripted report — but it does mean: **treat any Simulator
session driving this specific `ItemsView` sheet-handoff area via
`mcp__Claude_Code_iOS_Simulator__control` as unreliable for verification
purposes**, budget for it, and prefer physical-device verification for
anything touching this code path rather than spending repeated turns
retrying Simulator taps. FX-1/FX-2 both stopped their manual-verification
attempts here rather than continuing to chase this.

## Out of scope

- Fixing every downstream consequence of the bug speculatively before the
  root cause is understood — this is diagnosis-first

## Definition of done

Findings documented in this file (updated in place once known), fix
applied and verified if one was found and is small enough to land as part
of this spike, committed. If the fix is larger than a spike-sized change,
stop at documented findings + a follow-up ticket instead of scope-creeping
into a bigger fix here.

No fix was applied — no bug was reproduced to fix. This spike stops at
documented findings, per the "genuinely unresolved" branch of the
Definition of Done above; `status` is left as `ready` rather than `done`
because the physical-device acceptance criterion is explicitly unmet and
the user's original report is still unexplained.
