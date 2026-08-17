---
id: UX-3
epic: search-ux-refinement
title: Let search results be inspected for nutrition before picking one
status: ready
depends_on: [PA-3]
design_doc: null
---

# UX-3 — Let search results be inspected for nutrition before picking one

## Story

As a user searching by name, I want to check a candidate's nutrition facts
before committing to it, so I can tell "Banana (Morrisons)" apart from
"Banana (fairtrade)" by more than just the name and a thumbnail.

## Background

Direct feedback on PA-3: the search results list needs reworking. Right
now tapping a row immediately selects that product and starts the
save flow — there's no way to look closer first. Add a way to inspect a
candidate's nutrition, with proper back navigation, without disturbing the
existing "tap a row to pick it" behavior.

## Scope

- Add an info affordance (`info.circle`, the standard SF Symbol for "more
  details") to each row in `ProductSearchView`'s results list, as a
  **separate tap target from the row's main selection action** — tapping
  the row still selects-and-proceeds exactly as today; tapping the info
  icon does not.
- Tapping it **pushes** (via `NavigationLink`/`NavigationStack`
  navigation, not a `.sheet`) a detail view showing that candidate's
  available nutrition facts — reuse existing display components
  (`ProductDetailCard` and/or `MetricView`) rather than building new ones.
- Standard system back navigation (back button + edge-swipe gesture)
  returns to the results list, which must still reflect the same search —
  don't lose the query or re-run the search on return.
- **Known SwiftUI pitfall to avoid, with a proven fix already in this
  codebase:** a row that's itself a `Button` (or has `.onTapGesture`)
  wrapping *another* tappable control (the info icon) is exactly the
  nested-tappable-controls conflict `PackageVariantsView` hit and fixed —
  see its `row(for:)`: a plain `HStack` with `.contentShape(Rectangle())`
  + `.onTapGesture` for the row's primary action, and a separate,
  independently-tappable `Button` (`.buttonStyle(.plain)`) for the
  secondary action (there, the pencil-edit button; here, the info button).
  Apply the same structure rather than nesting `Button`-in-`Button`.

## Acceptance criteria

- [ ] Each search result row has a separate, reliably-tappable info button
- [ ] Tapping the info button pushes a nutrition detail view for that
      specific candidate; tapping elsewhere on the row still selects it
      directly, unaffected
- [ ] Back navigation (button and swipe gesture) returns to the results
      list with the same results still showing
- [ ] Row structure avoids the nested-tappable-controls pattern
      (`PackageVariantsView.row(for:)` is the reference fix)
- [ ] Manual verification: search, open a result's nutrition detail, go
      back, confirm results are unchanged, then select a different result
      and confirm it still proceeds to the save flow normally

## Out of scope

- Where search is triggered from (UX-1/UX-2)
- Any change to what happens after a result is *selected* (the existing
  confirm/configure/save flow is unaffected)

## Definition of done

Manual verification passed, docs updated if the row's interaction pattern
is worth calling out in AGENTS.md (optional — use judgment; it's already
documented once for `PackageVariantsView`, this may just be "same pattern,
applied again"), committed.
