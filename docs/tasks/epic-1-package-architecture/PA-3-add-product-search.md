---
id: PA-3
epic: package-architecture
title: Add product search (no-barcode acquisition)
status: backlog
depends_on: [PA-2]
design_doc: package-architecture.md#6-new-requirement-adding-a-product-without-scanning-a-barcode
---

# PA-3 — Add product search (no-barcode acquisition)

## Story

As a user, I want to find a product by name when it has no barcode to
scan, so I can add fresh produce and other unlabeled groceries to my
pantry.

## Scope

- `OpenFoodFactsService` gains
  `searchProducts(query: String) async throws -> [FoodProduct]`, hitting
  Open Food Facts' text-search endpoint. **Confirm the exact
  endpoint/response shape against OFF's current API when implementing** —
  the design doc deliberately doesn't commit to one; add an internal
  response-wrapper type if the search response shape differs from the
  existing by-barcode one.
- `FoodFoundation.ProductLookup` gains
  `search(query: String) async throws -> [Product]`, mapping each result
  via `Product.init(offProduct:)`.
- `ScannerView` gains a "Search by name" entry point alongside "Scan Food
  Barcode": a text field, a results list (name/brand/thumbnail), and
  picking a result feeds the *same* downstream flow a scan result would
  (`unitConfigFields`/`knownUnitFields`) — no new code path past that point.

## Acceptance criteria

- [ ] `OpenFoodFactsService.searchProducts` implemented, tested against
      representative fixture JSON (decode-based tests, matching this repo's
      existing `ProductMappingTests` style)
- [ ] `ProductLookup.search` implemented and unit tested — multi-result
      mapping; an empty result list is a valid, non-error outcome
- [ ] "Search by name" reachable from `ScannerView`
- [ ] Picking a search result flows into the existing unit-setup pipeline
      unchanged
- [ ] Manual verification on simulator/device: search finds a real generic
      product (e.g. "banana") and it can be saved into the pantry

## Out of scope

- MealKit's own search-sourced ingredient acquisition — that's MK-2, which
  depends on this task
- The "quick entry" (no-OFF-entry-at-all) escape hatch — stays deferred

## Definition of done

Tests pass, manual verification done on device/simulator, README.md /
AGENTS.md updated to describe search as a second acquisition path
alongside scanning, committed.
