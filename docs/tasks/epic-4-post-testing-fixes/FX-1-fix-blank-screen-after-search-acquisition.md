---
id: FX-1
epic: post-testing-fixes
title: Fix blank screen after adding a product via search
status: ready
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

- [ ] Reproduced and root-caused on the physical device
- [ ] Picking a search result reliably shows the confirm/configure/save
      screen on the first attempt, every time
- [ ] A visible loading state covers any in-flight `fetchFoodData` call, so
      a slow network response can never look identical to this bug
- [ ] Manual verification: search → pick a result → confirm the save screen
      appears immediately, repeated several times in a row without a retry
      ever being needed

## Out of scope

- BUG-1's own remaining physical-device confirmation (separate ticket) —
  only cross-reference if this turns out to be the same root cause

## Definition of done

Root cause fixed and verified on the physical device across several
repeated attempts, docs updated if the fix changes `ItemsView`'s documented
sheet-sequencing behavior, committed.
