---
id: UX-1
epic: search-ux-refinement
title: Add an acquisition menu to ItemsView (scan or search)
status: ready
depends_on: [PA-3]
design_doc: null
---

# UX-1 — Add an acquisition menu to ItemsView (scan or search)

## Story

As a user, I want to add a product straight from the Items list — by
scanning a barcode or searching by name — without first switching to the
Scan tab, so adding something is one tap away from wherever I already am.

## Background

PA-3 put "Search by Name" as a second button on the Scan tab, right next
to "Scan Food Barcode". In practice that placement doesn't work well (see
UX-2) — it's not where a user naturally looks for it, and cramming both
acquisition methods into one tab's button stack isn't how Apple apps
typically expose "more than one way to add something." The standard
pattern (Files, Photos, Reminders, etc.) is a **"•••" (more) menu** in the
navigation bar offering each option as a labeled menu item.

## Scope

- Add a toolbar `Menu` to `ItemsView`, trailing placement, using the
  standard "more" affordance (`ellipsis.circle` — check current HIG
  guidance for whether plain `ellipsis` is now preferred in toolbars, and
  match whichever Apple's own apps currently use).
- Two menu items, each an SF-Symbol-labeled action:
  - **Scan Barcode** (`barcode.viewfinder`) — opens the camera scanner.
  - **Search by Name** (`magnifyingglass`) — opens `ProductSearchView`.
- Both trigger the *same* underlying acquire → confirm → configure-unit →
  save flow that already exists (currently living in `ScannerView`) —
  **do not duplicate that logic.** The concrete reuse mechanism (present
  `ScannerView` itself as a sheet, parameterized to auto-start in scan or
  search mode; or extract a shared presentable component) is an
  implementation decision — resolve it however keeps the flow's logic in
  exactly one place. `ScannerView`'s own tab keeps working unchanged
  (barcode scanning only, per UX-2) — this menu is an *additional* entry
  point, not a replacement for the tab.
- Whichever reuse approach is chosen, the presented flow needs a way to
  dismiss back to `ItemsView` (a "Cancel"/"Done" toolbar button) if it
  doesn't already have one in its new presentation context.

## Acceptance criteria

- [ ] `ItemsView` has a "•••" toolbar menu with "Scan Barcode" and "Search
      by Name"
- [ ] Both menu items launch their respective flows without duplicating
      the acquire/confirm/configure/save logic already in `ScannerView`
- [ ] The presented flow can be dismissed back to `ItemsView`
- [ ] Saving a product from either path updates `ItemsView`'s list exactly
      as saving from the Scan tab already does
- [ ] Manual verification on simulator/device: add one product via the
      menu's scan option and one via its search option, confirm both land
      correctly in the Items list

## Out of scope

- Removing search from `ScannerView` — that's UX-2, sequenced after this
- Reworking the search results screen itself — that's UX-3

## Definition of done

Manual verification passed, docs updated (README.md/AGENTS.md — describe
the new menu and where the acquisition flow now lives/is shared from),
committed.
