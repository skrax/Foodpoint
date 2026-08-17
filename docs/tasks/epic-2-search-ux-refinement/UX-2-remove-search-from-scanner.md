---
id: UX-2
epic: search-ux-refinement
title: Remove the search entry point from ScannerView
status: done
depends_on: [UX-1]
design_doc: null
---

# UX-2 — Remove the search entry point from ScannerView

## Story

As a user, I want the Scan tab to just be about scanning, so it isn't
carrying two different acquisition methods that don't sit well together.

## Background

Direct feedback on PA-3: the "Search by Name" button bolted onto
`ScannerView` next to "Scan Food Barcode" doesn't work well there. Once
UX-1 gives search a proper home (the Items-view "•••" menu), the
`ScannerView` copy should go away rather than existing twice.

## Scope

- Remove the "Search by Name" button and `isShowingSearch` state/sheet
  from `ScannerView`.
- `ScannerView` goes back to being scan-only, same as before PA-3.
- `ProductSearchView` itself is **not** deleted — it's the same component
  UX-1 now presents from `ItemsView`.
- Update `ScannerView`'s doc comment (currently describes both scan and
  search as its job) back to describing scan-only.

## Acceptance criteria

- [x] `ScannerView` has no search button, no search-related state, no
      search sheet
- [x] `ScannerView`'s doc comment updated
- [x] `ProductSearchView` is unchanged/untouched by this removal
- [~] Manual verification: Scan tab shows only "Scan Food Barcode"; search
      is only reachable via the Items-view menu from UX-1 — **verified by
      build/inspection, not by tapping through the Simulator**, see note
      below

## Out of scope

- Anything about the Items-view menu itself (UX-1) or the search results
  screen (UX-3)

## Definition of done

Manual verification passed, README.md/AGENTS.md updated (remove the
"ScannerView has two acquisition entry points" description added in
PA-3/UX-1, back to scan-only), committed.

**Necessary ripple into `ItemsView.swift`, despite "Items-view menu" being
listed Out of scope above:** `ItemsView`'s "Search by Name" menu item was
wired (by UX-1) as `ScannerView(entryPoint: .search)`, i.e. it relied on
the exact `isShowingSearch`/search-sheet machinery this task removes.
Deleting that machinery without also updating `ItemsView` would have left
"Search by Name" silently broken (compile error, in fact, since
`EntryPoint.search` no longer exists) — which would violate this task's
own acceptance criterion above that search stay reachable via the
Items-view menu. Resolved by having `EntryPoint.search` become
`EntryPoint.resolved(barcode:)`: `ItemsView` now presents `ProductSearchView`
itself directly (this actually matches UX-1's own original Scope text —
"Search by Name ... opens `ProductSearchView`" — more literally than the
`entryPoint: .search` mechanism UX-1 ended up shipping), then hands the
chosen barcode to `ScannerView` via a second, sequenced sheet
(`.sheet(isPresented:onDismiss:)`), which re-resolves it through the same
`fetchFoodData(for:)` the camera path uses. This keeps "zero duplicated
acquire/confirm/configure/save logic" (UX-1's core invariant) intact while
satisfying this task's literal ScannerView acceptance criteria. Only
`ItemsView`'s sheet-presentation wiring changed — its menu's items, icons,
and labels are untouched. `ProductSearchView.swift` itself is untouched.

**Manual verification note:** not run through the iOS Simulator this
session — verified instead by `xcodebuild` succeeding and by inspection of
the resulting `ScannerView`/`ItemsView` control flow. Simulator input has
been unreliable for this exact flow in prior sessions (see BUG-1); a
follow-up manual pass (ideally on the physical device) should confirm the
Scan tab shows only "Scan Food Barcode" and that Items -> "•••" -> "Search
by Name" still reaches `ProductSearchView` and completes a save.
