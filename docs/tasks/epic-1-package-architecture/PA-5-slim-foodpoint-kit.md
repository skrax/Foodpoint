---
id: PA-5
epic: package-architecture
title: Slim FoodpointKit to a composition root
status: backlog
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

- [ ] `AppState.swift` reduced to the composition-root shape above
- [ ] Every view's call sites updated to `appState.pantry.*`
- [ ] Full app build succeeds (simulator + device)
- [ ] Manual smoke test on simulator/device: scan a product, save, adjust
      quantity, manage package sizes, manage nutrition — every existing
      feature works exactly as before the restructuring
- [ ] README.md / AGENTS.md updated to describe `AppState`'s new
      composition-root role and the `pantry` sub-store

## Out of scope

- Adding `meals: MealStore` — arrives with MK-1
- Any new behavior. This is a pure, behavior-preserving refactor.

## Definition of done

App builds and behaves identically to pre-restructuring. Manual smoke test
passed. Docs updated. Committed. **This is the checkpoint to verify the
full PA-1→PA-5 restructuring end-to-end before Epic 2 (Meals) begins.**
