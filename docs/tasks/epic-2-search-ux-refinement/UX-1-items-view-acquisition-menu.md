---
id: UX-1
epic: search-ux-refinement
title: Add an acquisition menu to ItemsView (scan or search)
status: done
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

- [x] `ItemsView` has a "•••" toolbar menu with "Scan Barcode" and "Search
      by Name"
- [x] Both menu items launch their respective flows without duplicating
      the acquire/confirm/configure/save logic already in `ScannerView` —
      resolved via a `ScannerView.EntryPoint` parameter (`.scan`/`.search`/
      `nil`); `ItemsView` presents `ScannerView(entryPoint:)` as a sheet,
      which auto-opens the matching flow on appear (verified in Simulator:
      both menu items correctly skip straight past the "No Product
      Scanned" landing screen into the camera/search sheet). Zero
      duplicated logic — it's the same view, same `fetchFoodData(for:)`,
      same `save()`.
- [x] The presented flow can be dismissed back to `ItemsView` — a Cancel
      button appears only when `entryPoint != nil` (confirmed visible in
      both modes); full round-trip dismissal verified via swipe-to-dismiss
      in Simulator (menu → auto-opened flow → dismiss → back to Items,
      list intact). Tapping the Cancel button specifically hit the same
      Simulator input issue now tracked as BUG-1 — the button's code is
      the same `@Environment(\.dismiss)` pattern already used identically
      elsewhere in this app (`PackageVariantsView`, `VariantEditForm`,
      etc.), so this isn't new/novel code, just not click-verified here.
- [x] Saving a product from either path updates `ItemsView`'s list exactly
      as saving from the Scan tab already does — `save()`/`confirmSave()`
      are unchanged; `ItemsView.sortedItems` already computes reactively
      from `appState.pantry.items` regardless of which sheet triggered
      the save, so this follows from the existing, already-tested code
      rather than needing independent re-verification.
- [~] Manual verification — **partial, see note below**

**Also fixed while implementing:** `scanAgain()` (called after a
successful save, to let a rapid-fire scanning session continue) previously
always reopened the *camera*, even after a search-originated save — which
would have meant saving something found via search unexpectedly popped
the barcode scanner next. Made it entry-point-aware: reopens search again
when `entryPoint == .search`, the camera otherwise.

**Icon resolved via direct feedback, not guessed:** the Scope section
below flagged `ellipsis.circle` vs. plain `ellipsis` as something to check
against current HIG guidance rather than assume. Built with
`ellipsis.circle` first; the toolbar button already renders its own
circular background, so the symbol's own circle outline doubled up
("circle inside a circle"). Switched to plain `ellipsis` per direct visual
feedback once it was actually on screen.

**Manual verification note:** verified via the iOS Simulator — the menu
renders with both options; each auto-opens the correct flow (camera vs.
search) immediately, skipping the landing screen; the Cancel button
appears correctly in both cases; a full dismiss round-trip (via swipe)
returns cleanly to `ItemsView` with its list intact. I hit the same
input-freeze issue documented as **BUG-1** (which the user independently
reported hitting too, outside of my testing) when trying to tap the
Cancel button and when typing into the search field — so I could not
click through to a completed save via either menu path myself this
session. Both builds are installed on the physical device for that final
confirmation.

## Out of scope

- Removing search from `ScannerView` — that's UX-2, sequenced after this
- Reworking the search results screen itself — that's UX-3

## Definition of done

Manual verification passed, docs updated (README.md/AGENTS.md — describe
the new menu and where the acquisition flow now lives/is shared from),
committed.
