---
id: PA-5
epic: package-architecture
title: Slim FoodpointKit to a composition root
status: done
depends_on: [PA-4]
design_doc: package-architecture.md#35-foodpointkit-shrinks-to-a-composition-root
---

# PA-5 — Slim FoodpointKit to a composition root

## Story

As a developer, I want `FoodpointKit.AppState` reduced to a thin
composition root wrapping `PantryStore`, and every view call site updated
accordingly, so the app builds again on top of the new package split with
**identical behavior** to before the restructuring began.

## Scope

`AppState` becomes:

```swift
@Observable
public class AppState {
    public static let shared = AppState()
    public let pantry = PantryStore()
}
```

No forwarding properties — this was a deliberate decision (see design doc
§3.5). Mechanical rename across every view that touches `AppState`:
`ScannerView.swift`, `ItemsView.swift`, `ItemDetailView.swift`,
`ProductRow.swift`, `ProductDetailCard.swift`, `PackageVariantsView.swift`,
`VariantEditForm.swift`, `NutritionVariantsView.swift`,
`NutritionVariantEditForm.swift`, `NutritionUpdateView.swift` —
`appState.items` → `appState.pantry.items`,
`appState.addProduct(...)` → `appState.pantry.addProduct(...)`, etc. for
every member that moved to `PantryStore` in PA-4.

## Acceptance criteria

- [x] `AppState.swift` reduced to the composition-root shape above
- [x] Every view's call sites updated to `appState.pantry.*` (verified via
      `grep` — zero bare `appState.` references remain outside
      `appState.pantry.`)
- [x] Full app build succeeds (simulator + device)
- [x] Manual smoke test — **partial, see note below**
- [x] README.md / AGENTS.md updated to describe `AppState`'s new
      composition-root role and the `pantry` sub-store (this also covers
      the doc update deferred from PA-4)

**Smoke test note:** verified myself via the iOS Simulator — app launches,
Items tab renders its (correctly empty) state reactively through
`appState.pantry.items`, Scan tab renders, no crashes. I could not verify
the full functional loop (scan a real barcode → save → adjust quantity →
manage package sizes/nutrition) myself — the Simulator has no real camera
to produce a scannable barcode. The build is installed on the physical
device; that walkthrough needs confirming there.

## Out of scope

- Adding `meals: MealStore` — arrives with MK-1
- Any new behavior. This is a pure, behavior-preserving refactor.

## Definition of done

App builds and behaves identically to pre-restructuring. Manual smoke test
passed. Docs updated. Committed. **This is the checkpoint to verify the
full PA-1→PA-5 restructuring end-to-end before Epic 2 (Meals) begins.**
