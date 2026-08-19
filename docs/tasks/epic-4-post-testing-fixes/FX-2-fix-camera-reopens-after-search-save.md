---
id: FX-2
epic: post-testing-fixes
title: Don't reopen the camera after saving a product added via search
status: ready
depends_on: [UX-2]
design_doc: null
---

# FX-2 — Don't reopen the camera after saving a product added via search

## Story

As a user who added a product by searching for it (not by scanning), I
don't want the barcode scanner's camera to pop open right after I save it —
I never asked to scan anything.

## Background

**User-reported, on the physical device**: adding an item via "Search by
Name" and completing the save opens the camera scanner.

Root cause is identified in `Foodpoint/ScannerView.swift`'s `scanAgain()`
(called after a successful save to reset for the next acquisition):

> "Always the camera now — `ScannerView` is scan-only, so there's no other
> acquisition method to return to even when this presentation was entered
> via `.resolved(barcode:)` (a search-originated save completing here still
> just goes back to scanning, the same as any other save)."

That was a deliberate call made during UX-2 (`ScannerView` has exactly one
acquisition method now, the camera, so "go back to scanning" seemed like
the only option) — but in practice it's a jarring surprise for a save that
started from search: the user gets a camera viewfinder they never asked
for, for an acquisition method they weren't using.

## Scope

- After a save completes for a `.resolved(barcode:)`-entered presentation
  (i.e. the flow started from `ItemsView`'s "Search by Name", not "Scan
  Barcode"), don't call `scanAgain()`/open the camera. Instead dismiss back
  to `ItemsView` (or land on a neutral "saved" state — use judgment for
  whatever reads best, consistent with how `.scan`-entered presentations
  already behave after a save).
- `.scan`-entered presentations (camera-originated) should keep their
  current "ready to scan the next item" behavior via `scanAgain()`
  unchanged — this is specifically about not doing that for `.resolved`.
- Update `scanAgain()`'s doc comment, which currently documents the exact
  behavior this task removes.

## Acceptance criteria

- [ ] Saving a product added via "Search by Name" does not open the camera
      afterward
- [ ] Saving a product added via "Scan Barcode" still returns to a
      ready-to-scan camera state afterward, unchanged
- [ ] `scanAgain()`'s doc comment updated to match
- [ ] Manual verification on the physical device: add a product via search,
      save it, confirm no camera appears; separately, scan a barcode, save
      it, confirm the camera is still ready for the next scan as before

## Out of scope

- FX-1's blank-screen bug (separate, though in the same handoff code path —
  fix independently; if fixing one makes the other trivial, that's fine)

## Definition of done

Manual verification passed on the physical device for both entry points,
docs updated, committed.
