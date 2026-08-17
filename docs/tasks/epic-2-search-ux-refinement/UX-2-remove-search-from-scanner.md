---
id: UX-2
epic: search-ux-refinement
title: Remove the search entry point from ScannerView
status: backlog
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

- [ ] `ScannerView` has no search button, no search-related state, no
      search sheet
- [ ] `ScannerView`'s doc comment updated
- [ ] `ProductSearchView` is unchanged/untouched by this removal
- [ ] Manual verification: Scan tab shows only "Scan Food Barcode"; search
      is only reachable via the Items-view menu from UX-1

## Out of scope

- Anything about the Items-view menu itself (UX-1) or the search results
  screen (UX-3)

## Definition of done

Manual verification passed, README.md/AGENTS.md updated (remove the
"ScannerView has two acquisition entry points" description added in
PA-3/UX-1, back to scan-only), committed.
