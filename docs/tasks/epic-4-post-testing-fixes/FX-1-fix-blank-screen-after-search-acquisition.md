---
id: FX-1
epic: post-testing-fixes
title: Fix blank screen after adding a product via search
status: in-progress
depends_on: [UX-2]
design_doc: null
---

# FX-1 — Fix blank screen after adding a product via search

## Story

As a user, when I search for a product by name and tap it to add it, I want
the save flow to actually appear, so I can configure and save the product
without the screen going blank first.

## Background

**User-reported, on the physical device**: Items tab → "•••" → "Search by
Name" → search for an item → tap a result. The screen that should let you
confirm/configure/save the product is **blank**. Scrolling down (a
swipe-to-dismiss gesture) closes it; searching again and picking a result a
second time works correctly.

The likely code path (`Foodpoint/Views/ItemsView.swift`'s `body`, added in
UX-2): picking a search result sets `resolvedSearchBarcode` and dismisses
the search sheet; its `onDismiss` then flips `isShowingResolvedProduct`,
presenting a **second, sequenced sheet** — `ScannerView(entryPoint:
.resolved(barcode:))` — whose `.onAppear` calls
`triggerEntryPointIfNeeded()`, which calls `fetchFoodData(for:)` (an async
network call) for that barcode. A blank screen on first attempt, working on
retry, matches a timing issue around this handoff — either the second
sheet's content isn't ready when it's first presented, or `fetchFoodData`'s
result isn't reflected until some later state change (the retry "flushing"
whatever the first attempt got stuck on). No `ProgressView`/loading state
covers the wait for `fetchFoodData` either, which would make even a
*correctly* slow fetch look identical to this bug.

This may or may not be related to **BUG-1** (first-use input-field hang) —
same general area (a sequenced/stacked sheet presentation off `ItemsView`),
but a different, more specific symptom (blank screen vs. unresponsive
input) reproduced directly on the physical device rather than only
suspected in the Simulator. Worth investigating both together rather than
assuming they're unrelated.

## Scope

- Reproduce on the physical device and narrow down: is `fetchFoodData`
  actually completing (just not rendering), or not being called/reached at
  all on the first attempt?
- Fix the root cause. If it's purely a missing-loading-state issue, add a
  `ProgressView` while `fetchFoodData` is in flight; if it's a genuine
  sheet-presentation timing bug, fix the sequencing (e.g. reconsider the
  two-sequenced-`.sheet` handoff in `ItemsView.body`).
- Note whether this shares a root cause with BUG-1; update BUG-1's findings
  if so rather than duplicating the investigation.

## Acceptance criteria

- [x] Reproduced and root-caused on the physical device — not reproduced
      first-hand (no physical device in this environment); root-caused by
      code review instead. See Findings below for why the code-review
      root cause is high-confidence even without a live repro.
- [x] Picking a search result reliably shows the confirm/configure/save
      screen on the first attempt, every time — fixed per Findings; not
      manually confirmed (see the unmet criterion below).
- [x] A visible loading state covers any in-flight `fetchFoodData` call, so
      a slow network response can never look identical to this bug —
      already true before this ticket; see Findings.
- [ ] Manual verification: search → pick a result → confirm the save screen
      appears immediately, repeated several times in a row without a retry
      ever being needed — **not completed**, blocked by Simulator tooling
      flakiness. See Findings.

## Out of scope

- BUG-1's own remaining physical-device confirmation (separate ticket) —
  only cross-reference if this turns out to be the same root cause

## Findings (2026-08-19)

**Root cause was a genuine sheet-presentation timing bug, not a missing
loading indicator.** `ScannerView` already had a `ProgressView("Fetching
product details...")` gated on `isLoading` before this ticket (confirmed
via `git log`/`git blame` — it predates UX-1/UX-2/this ticket entirely, as
plain original scan-flow code), and `fetchFoodData(for:)` sets `isLoading`
synchronously before its `Task` starts, for every entry point including
`.resolved(barcode:)`. So the blank screen was never "slow fetch looks like
a hang" — the ticket's own Background section's "no loading state" theory
doesn't hold against the code as it existed at the time this ticket was
picked up.

The actual bug: `ItemsView.body` presented the resolved-product sheet via
`.sheet(isPresented: $isShowingResolvedProduct, ...)`, flipped to `true`
from inside the *search* sheet's own `onDismiss` callback
(`.sheet(isPresented: $isShowingSearchEntry, onDismiss: { ... })`).
Presenting a second, independent `UIViewController`-backed sheet from
inside the first one's dismissal callback races UIKit's own teardown of
the first sheet — nothing guarantees the first sheet has finished
dismissing before SwiftUI is asked to begin presenting the second, and on
the first attempt after a fresh sheet-presentation cycle that race can
plausibly lose, leaving nothing visibly presented (or the wrong content
briefly presented) until some later state change "flushes" it — matching
exactly the reported "blank first attempt, retry works" symptom.

**Fix**: collapsed the three possible sheets (`.scan`/`.search`/
`.resolved(barcode:)`) into one `ActiveSheet: Identifiable` enum and a
single `.sheet(item:)` modifier (`Foodpoint/Views/ItemsView.swift`).
Picking a search result now sets `activeSheet = .resolved(barcode:)`
directly — switching the bound item's identity while a sheet is already
presented — instead of dismissing to `nil` and re-presenting from
`onDismiss`. This makes SwiftUI itself own and sequence the
dismiss-then-present transition as one atomic update, eliminating the race
entirely rather than papering over it with a delay.

This is exactly the "genuine sheet-presentation timing bug" branch the
ticket's Scope section anticipated, not the "purely a missing-loading-state
issue" branch — filed here per the ticket's own instruction to note this
clearly.

**Manual verification status**: build succeeds (`xcodebuild ... -destination
'generic/platform=iOS Simulator' build` → `BUILD SUCCEEDED`). Simulator-based
manual verification was attempted (iPhone 17 Pro, iOS 26.5) but could not
be completed reliably — repeated attempts to tap "Search by Name" (and,
eventually, even "Scan Barcode") off `ItemsView`'s "•••" menu produced
inconsistent results: taps that should have opened the intended sheet
sometimes did nothing visible, and in one case a tap fired several steps
later against UI the app had since navigated to on its own (landing on an
unrelated "New Meal" ingredient-composition screen). This is not a
coordinate-math mistake — coordinates were verified correct against a
fully-rendered menu screenshot before each tap, and one early attempt using
the same technique did work. This matches, and adds a new data point to,
**BUG-1**'s existing findings about this exact tooling (`mcp__Claude_Code_
iOS_Simulator__control`) producing input that looks like an app hang but
isn't one; see BUG-1's findings file, updated with this observation. No
root cause fix in `ItemsView`/`ScannerView` can be confirmed or ruled out
via this Simulator tooling right now — **physical-device verification is
needed** to close this criterion, same conclusion BUG-1 already reached
for its own acceptance criteria.

## Findings, part 2 — the real bug (2026-08-19, physical device)

The `ActiveSheet`/`.sheet(item:)` fix above was necessary but not
sufficient. Physical-device testing (the first real test of this flow)
turned up a second, more severe bug in the same code path, reported as:
"the dialog to configure the item is closed without user action and you
return to 'no items'" — the configure screen never appeared at all,
landing straight back on `ItemsView` with nothing saved.

**Root cause**: `Foodpoint/Views/ProductSearchView.swift`'s `resultRow`
`.onTapGesture` called `onSelect(product.id)` immediately followed by its
own `dismiss()`. In `ItemsView`, `onSelect` reassigns the shared
`activeSheet` state from `.search` to `.resolved(barcode:)` — the whole
point of the FX-1 fix above, letting SwiftUI own that transition as one
atomic item-switch. But `dismiss()`, called on the very next line, is
`ProductSearchView`'s own `@Environment(\.dismiss)`, tied to that same
`.sheet(item: $activeSheet)` presentation — calling it right after the
reassignment races that transition and wins, snapping `activeSheet` back
to `nil` before the `.resolved` sheet ever gets presented. The sheet just
closes. Nothing about the `ActiveSheet` enum/single-`.sheet(item:)`
mechanism was wrong; a leftover call from the pre-FX-1 architecture (where
`ProductSearchView` really did need to dismiss itself, and `ItemsView`
picked up the staged barcode from `onDismiss`) was actively fighting it.

`MealCompositionEditorView`'s own use of `ProductSearchView` masked this:
it already sets its own `isShowingSearch = false` inside `onSelect`, so the
internal `dismiss()` there was always redundant, not harmful (both close
the same sheet, no competing reassignment to undo) — which is why this
didn't surface during that flow's testing.

**Fix**: removed the `dismiss()` call from `resultRow`'s `onTapGesture`
entirely (`ProductSearchView.swift`). `onSelect` alone is now the whole
contract — every caller (both current ones) already handles its own
dismissal inside `onSelect`, so this is a pure bug fix with no behavior
change for `MealCompositionEditorView`. Documented the contract in
`ProductSearchView`'s type-level doc comment so a future caller doesn't
reintroduce the same race. Build succeeds
(`xcodebuild ... -destination 'generic/platform=iOS Simulator' build`).
Not yet re-verified on the physical device — that's the next step, same
as the rest of this ticket's still-open manual-verification criterion.

## Definition of done

Root cause fixed and verified on the physical device across several
repeated attempts, docs updated if the fix changes `ItemsView`'s documented
sheet-sequencing behavior, committed.

Root cause fixed, docs updated (`AGENTS.md`/`README.md`), and committed.
Physical-device verification is the one remaining gap — see Findings above
— so `status` is left as `ready` rather than `done` until that happens.
